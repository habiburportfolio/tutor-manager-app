import 'package:flutter/foundation.dart';
import '../services/db_service.dart';

/// Stores pluggable configuration for SMS gateway, Payment gateway (SSLCommerz, bKash, Nagad),
/// and Supabase Cloud Backup / Multi-device Sync.
class SettingsProvider extends ChangeNotifier {
  late final _box = DBService.box(DBService.settingsBox);

  // SMS Gateway settings
  String get smsProviderName =>
      _box.get('smsProviderName', defaultValue: 'BulkSMSBD');
  String get smsApiUrl => _box.get('smsApiUrl', defaultValue: '');
  String get smsApiKey => _box.get('smsApiKey', defaultValue: '');
  String get smsSenderId => _box.get('smsSenderId', defaultValue: '');

  // Payment gateway settings (SSLCommerz / bKash / Nagad)
  String get paymentGateway =>
      _box.get('paymentGateway', defaultValue: 'SSLCommerz');
  String get paymentStoreId => _box.get('paymentStoreId', defaultValue: '');
  String get paymentApiKey => _box.get('paymentApiKey', defaultValue: '');
  bool get paymentLiveMode => _box.get('paymentLiveMode', defaultValue: false);

  // Supabase Cloud Backup & Multi-device Sync settings
  String get supabaseUrl => _box.get('supabaseUrl', defaultValue: '');
  String get supabaseAnonKey => _box.get('supabaseAnonKey', defaultValue: '');
  bool get supabaseAutoSync =>
      _box.get('supabaseAutoSync', defaultValue: false);
  String get lastSyncTimestamp =>
      _box.get('lastSyncTimestamp', defaultValue: '');

  // Coaching center info (used on receipts)
  String get centerName =>
      _box.get('centerName', defaultValue: 'My Coaching Center');
  String get centerPhone => _box.get('centerPhone', defaultValue: '');
  String get centerAddress => _box.get('centerAddress', defaultValue: '');

  Future<void> saveSmsSettings({
    required String providerName,
    required String apiUrl,
    required String apiKey,
    required String senderId,
  }) async {
    await _box.put('smsProviderName', providerName);
    await _box.put('smsApiUrl', apiUrl);
    await _box.put('smsApiKey', apiKey);
    await _box.put('smsSenderId', senderId);
    notifyListeners();
  }

  Future<void> savePaymentSettings({
    required String gateway,
    required String storeId,
    required String apiKey,
    required bool liveMode,
  }) async {
    await _box.put('paymentGateway', gateway);
    await _box.put('paymentStoreId', storeId);
    await _box.put('paymentApiKey', apiKey);
    await _box.put('paymentLiveMode', liveMode);
    notifyListeners();
  }

  Future<void> saveSupabaseSettings({
    required String url,
    required String anonKey,
    required bool autoSync,
  }) async {
    await _box.put('supabaseUrl', url);
    await _box.put('supabaseAnonKey', anonKey);
    await _box.put('supabaseAutoSync', autoSync);
    notifyListeners();
  }

  Future<void> setLastSyncTimestamp(String isoString) async {
    await _box.put('lastSyncTimestamp', isoString);
    notifyListeners();
  }

  Future<void> saveCenterInfo({
    required String name,
    required String phone,
    required String address,
  }) async {
    await _box.put('centerName', name);
    await _box.put('centerPhone', phone);
    await _box.put('centerAddress', address);
    notifyListeners();
  }
}
