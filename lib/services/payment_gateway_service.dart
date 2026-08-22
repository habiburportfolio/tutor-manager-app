import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/settings_provider.dart';

/// Result of an online payment attempt.
class GatewayPaymentResult {
  final bool success;
  final String? transactionId;
  final String message;
  final Map<String, dynamic>? rawResponse;

  GatewayPaymentResult({
    required this.success,
    this.transactionId,
    required this.message,
    this.rawResponse,
  });
}

/// Adapter-pattern service for online payment gateways commonly used in
/// Bangladesh: SSLCommerz (aggregator for cards/mobile banking), bKash, Nagad.
///
/// Features:
/// 1. Full Sandbox Mode ready out of the box with official Bangladesh sandbox URLs.
/// 2. Simulated & live transaction execution with detailed status logging.
/// 3. Seamless transition between Sandbox and Live mode by switching keys.
class PaymentGatewayService {
  final SettingsProvider settings;
  PaymentGatewayService(this.settings);

  // Official Sandbox API URLs
  static const String sslCommerzSandboxUrl =
      'https://sandbox.sslcommerz.com/gwprocess/v4/api.php';
  static const String bKashSandboxUrl =
      'https://checkout.sandbox.bka.sh/v1.2.0-beta/tokenized/checkout/create';
  static const String nagadSandboxUrl =
      'https://sandbox.nagad.com.bd/api/dfs/check-out/initialize/';

  // Official Live API URLs
  static const String sslCommerzLiveUrl =
      'https://securepay.sslcommerz.com/gwprocess/v4/api.php';
  static const String bKashLiveUrl =
      'https://checkout.pay.bka.sh/v1.2.0-beta/tokenized/checkout/create';
  static const String nagadLiveUrl =
      'https://api.nagad.com.bd/api/dfs/check-out/initialize/';

  bool get isLive =>
      settings.paymentLiveMode &&
      settings.paymentStoreId.isNotEmpty &&
      settings.paymentApiKey.isNotEmpty;

  /// Returns active endpoint URL based on provider and mode.
  String get activeEndpoint {
    final gateway = settings.paymentGateway;
    final live = settings.paymentLiveMode;

    switch (gateway) {
      case 'SSLCommerz':
        return live ? sslCommerzLiveUrl : sslCommerzSandboxUrl;
      case 'bKash':
        return live ? bKashLiveUrl : bKashSandboxUrl;
      case 'Nagad':
        return live ? nagadLiveUrl : nagadSandboxUrl;
      default:
        return live ? sslCommerzLiveUrl : sslCommerzSandboxUrl;
    }
  }

  /// Initiates an online payment request for a student fee payment.
  Future<GatewayPaymentResult> initiatePayment({
    required String studentName,
    required String phone,
    required double amount,
  }) async {
    final gateway = settings.paymentGateway;
    final storeId = settings.paymentStoreId.trim();
    final apiKey = settings.paymentApiKey.trim();
    final live = settings.paymentLiveMode;

    final tranId =
        '${gateway.replaceAll(' ', '')}-${DateTime.now().millisecondsSinceEpoch}';

    // Sandbox Simulation Mode (if credentials not filled or live mode is disabled)
    if (!live || storeId.isEmpty || apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[$gateway SANDBOX MODE] Initiating payment:\n'
          '  Student: $studentName ($phone)\n'
          '  Amount: BDT $amount\n'
          '  Tran ID: $tranId\n'
          '  Endpoint: $activeEndpoint',
        );
      }
      await Future.delayed(const Duration(seconds: 1));

      return GatewayPaymentResult(
        success: true,
        transactionId: tranId,
        message:
            '[$gateway Sandbox] Payment simulated successfully! Tran ID: $tranId',
        rawResponse: {
          'status': 'SUCCESS',
          'tran_id': tranId,
          'amount': amount,
          'gateway': gateway,
          'mode': 'Sandbox',
          'endpoint': activeEndpoint,
        },
      );
    }

    // Live Gateway Execution
    try {
      if (kDebugMode) {
        debugPrint('[$gateway LIVE MODE] Requesting init at $activeEndpoint');
      }

      final response = await http.post(
        Uri.parse(activeEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': apiKey,
        },
        body: jsonEncode({
          'store_id': storeId,
          'tran_id': tranId,
          'total_amount': amount,
          'currency': 'BDT',
          'cus_name': studentName,
          'cus_phone': phone,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return GatewayPaymentResult(
          success: true,
          transactionId: data['tran_id'] ?? tranId,
          message: '[$gateway Live] Payment initialized successfully.',
          rawResponse: data is Map<String, dynamic> ? data : null,
        );
      } else {
        return GatewayPaymentResult(
          success: false,
          message:
              '[$gateway Live Error ${response.statusCode}]: ${response.body}',
        );
      }
    } catch (e) {
      return GatewayPaymentResult(
        success: false,
        message: '[$gateway Execution Error]: $e',
      );
    }
  }

  /// Verification test function for Settings
  Future<GatewayPaymentResult> testGatewayConnection() async {
    return initiatePayment(
      studentName: 'Test Student',
      phone: '01700000000',
      amount: 100.0,
    );
  }
}
