import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../providers/settings_provider.dart';

class SmsResult {
  final bool success;
  final String message;
  final int? statusCode;

  SmsResult({
    required this.success,
    required this.message,
    this.statusCode,
  });
}

/// Pluggable SMS gateway adapter with pre-configured provider templates
/// for Bangladeshi providers (GP, Robi, BulkSMSBD, Greenweb) and custom APIs.
class SmsService {
  final SettingsProvider settings;
  SmsService(this.settings);

  /// Standard provider API URL templates
  static const Map<String, String> providerPresets = {
    'BulkSMSBD':
        'http://bulksmsbd.net/api/smsapi?api_key={apikey}&type=text&number={phone}&senderid={senderid}&message={message}',
    'GP SMS Gateway':
        'https://gpmmp.grameenphone.com/api/v1/send?apikey={apikey}&msisdn={phone}&message={message}&sender={senderid}',
    'Robi SMS Gateway':
        'https://api.robi.com.bd/sms/v1/send?apiKey={apikey}&mobile={phone}&sms={message}',
    'Greenweb BD':
        'https://api.greenweb.com.bd/api.php?token={apikey}&to={phone}&message={message}',
    'Custom Provider': '',
  };

  /// Returns preset template for a given provider name
  static String getPresetUrl(String providerName) {
    return providerPresets[providerName] ?? '';
  }

  /// Sends an SMS to a single phone number.
  Future<bool> sendSms({required String phone, required String message}) async {
    final result = await sendSmsDetailed(phone: phone, message: message);
    return result.success;
  }

  /// Sends an SMS and returns detailed status/response message.
  Future<SmsResult> sendSmsDetailed({
    required String phone,
    required String message,
  }) async {
    final apiUrl = settings.smsApiUrl.trim();
    final apiKey = settings.smsApiKey.trim();
    final senderId = settings.smsSenderId.trim();

    if (apiUrl.isEmpty) {
      if (kDebugMode) {
        debugPrint('SMS not sent: no SMS provider API URL configured.');
      }
      return SmsResult(
        success: false,
        message: 'No SMS Provider API URL configured in Settings.',
      );
    }

    try {
      final formattedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final url = apiUrl
          .replaceAll('{phone}', Uri.encodeComponent(formattedPhone))
          .replaceAll('{message}', Uri.encodeComponent(message))
          .replaceAll('{apikey}', Uri.encodeComponent(apiKey))
          .replaceAll('{senderid}', Uri.encodeComponent(senderId));

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      if (kDebugMode) {
        debugPrint('SMS API response [${response.statusCode}]: ${response.body}');
      }

      return SmsResult(
        success: isSuccess,
        statusCode: response.statusCode,
        message: isSuccess
            ? 'SMS sent successfully (${response.statusCode})'
            : 'SMS provider error (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SMS send exception: $e');
      }
      return SmsResult(
        success: false,
        message: 'Failed to send SMS: $e',
      );
    }
  }

  /// Sends a test SMS to verify the configured gateway credentials.
  Future<SmsResult> sendTestSms(String testPhone) async {
    return sendSmsDetailed(
      phone: testPhone,
      message: 'Test SMS from Tutor Manager Coaching System.',
    );
  }

  /// Sends bulk SMS to a list of phone numbers.
  Future<Map<String, bool>> sendBulkSms({
    required List<String> phones,
    required String message,
  }) async {
    final results = <String, bool>{};
    for (final phone in phones) {
      results[phone] = await sendSms(phone: phone, message: message);
    }
    return results;
  }
}
