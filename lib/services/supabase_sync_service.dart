import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/settings_provider.dart';
import 'db_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final DateTime? timestamp;

  SyncResult({
    required this.success,
    required this.message,
    this.timestamp,
  });
}

/// Abstract Cloud Sync Adapter Interface.
/// Follows local-first architecture — all reads & writes occur on local Hive DB.
/// Cloud sync runs asynchronously in the background or on-demand without blocking the UI.
abstract class ISyncAdapter {
  Future<SyncResult> backupToCloud();
  Future<SyncResult> restoreFromCloud();
  Future<SyncResult> testConnection();
}

/// Supabase Cloud Backup & Multi-device Synchronization Implementation.
class SupabaseSyncService implements ISyncAdapter {
  final SettingsProvider settings;
  SupabaseSyncService(this.settings);

  bool get isConfigured =>
      settings.supabaseUrl.isNotEmpty && settings.supabaseAnonKey.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apikey': settings.supabaseAnonKey,
        'Authorization': 'Bearer ${settings.supabaseAnonKey}',
        'Prefer': 'return=minimal',
      };

  @override
  Future<SyncResult> testConnection() async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'Supabase URL and Anon Key are not configured in Settings.',
      );
    }

    try {
      final cleanUrl = settings.supabaseUrl.trim().replaceAll(RegExp(r'/$'), '');
      final endpoint = Uri.parse('$cleanUrl/rest/v1/');

      final response = await http
          .get(endpoint, headers: _headers)
          .timeout(const Duration(seconds: 10));

      final isOk = response.statusCode >= 200 && response.statusCode < 400;
      return SyncResult(
        success: isOk,
        message: isOk
            ? 'Successfully connected to Supabase Cloud.'
            : 'Supabase returned status code: ${response.statusCode}',
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Could not connect to Supabase: $e',
      );
    }
  }

  @override
  Future<SyncResult> backupToCloud() async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'Please enter Supabase URL and Anon Key first.',
      );
    }

    try {
      final payload = _exportHiveBoxesToJson();
      final cleanUrl = settings.supabaseUrl.trim().replaceAll(RegExp(r'/$'), '');
      
      // We send backup payload to 'coaching_backups' table or storage RPC endpoint
      final endpoint = Uri.parse('$cleanUrl/rest/v1/coaching_backups');

      if (kDebugMode) {
        debugPrint('Supabase Backup initiating to $endpoint...');
      }

      final response = await http
          .post(
            endpoint,
            headers: _headers,
            body: jsonEncode({
              'device_id': 'flutter-app-main',
              'updated_at': DateTime.now().toIso8601String(),
              'data': payload,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final now = DateTime.now();
      await settings.setLastSyncTimestamp(now.toIso8601String());

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      return SyncResult(
        success: isSuccess,
        timestamp: now,
        message: isSuccess
            ? 'Cloud backup successfully completed!'
            : 'Backup response (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Supabase backup error: $e');
      }
      return SyncResult(
        success: false,
        message: 'Backup failed: $e',
      );
    }
  }

  @override
  Future<SyncResult> restoreFromCloud() async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'Please enter Supabase URL and Anon Key first.',
      );
    }

    try {
      final cleanUrl = settings.supabaseUrl.trim().replaceAll(RegExp(r'/$'), '');
      final endpoint = Uri.parse(
          '$cleanUrl/rest/v1/coaching_backups?order=updated_at.desc&limit=1');

      final response = await http
          .get(endpoint, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List list = jsonDecode(response.body);
        if (list.isEmpty) {
          return SyncResult(
            success: false,
            message: 'No cloud backups found on Supabase.',
          );
        }

        final latestBackup = list.first;
        final data = latestBackup['data'] as Map<String, dynamic>?;

        if (data != null) {
          await _importJsonToHiveBoxes(data);
          final now = DateTime.now();
          await settings.setLastSyncTimestamp(now.toIso8601String());

          return SyncResult(
            success: true,
            timestamp: now,
            message: 'Cloud backup successfully restored to local database!',
          );
        }
      }

      return SyncResult(
        success: false,
        message:
            'Failed to fetch backup (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Restore failed: $e',
      );
    }
  }

  /// Serializes all local Hive boxes into a single map object
  Map<String, dynamic> _exportHiveBoxesToJson() {
    final Map<String, dynamic> exportMap = {};

    final boxes = [
      DBService.studentsBox,
      DBService.classesBox,
      DBService.sectionsBox,
      DBService.subjectsBox,
      DBService.paymentsBox,
      DBService.expensesBox,
      DBService.homeworkBox,
      DBService.settingsBox,
    ];

    for (final boxName in boxes) {
      final box = DBService.box(boxName);
      final boxData = <String, dynamic>{};
      for (final key in box.keys) {
        boxData[key.toString()] = box.get(key);
      }
      exportMap[boxName] = boxData;
    }

    return exportMap;
  }

  /// Imports data into local Hive boxes
  Future<void> _importJsonToHiveBoxes(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      final boxName = entry.key;
      final boxMap = entry.value;

      if (boxMap is Map) {
        final box = DBService.box(boxName);
        await box.clear();
        for (final item in boxMap.entries) {
          await box.put(item.key, item.value);
        }
      }
    }
  }
}
