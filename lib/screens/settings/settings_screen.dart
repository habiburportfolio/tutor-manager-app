import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/sms_service.dart';
import '../../services/payment_gateway_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final settings = context.read<SettingsProvider>();

  // Coaching Center Info
  late final _centerNameCtrl = TextEditingController(text: settings.centerName);
  late final _centerPhoneCtrl =
      TextEditingController(text: settings.centerPhone);
  late final _centerAddressCtrl =
      TextEditingController(text: settings.centerAddress);

  // SMS Gateway
  late String _smsPreset = settings.smsProviderName.isEmpty
      ? 'BulkSMSBD'
      : settings.smsProviderName;
  late final _smsUrlCtrl = TextEditingController(
    text: settings.smsApiUrl.isEmpty
        ? SmsService.getPresetUrl('BulkSMSBD')
        : settings.smsApiUrl,
  );
  late final _smsKeyCtrl = TextEditingController(text: settings.smsApiKey);
  late final _smsSenderCtrl =
      TextEditingController(text: settings.smsSenderId);
  bool _testingSms = false;

  // Payment Gateway
  late String _paymentGateway = settings.paymentGateway;
  late final _storeIdCtrl = TextEditingController(
    text: settings.paymentStoreId,
  );
  late final _apiKeyCtrl = TextEditingController(text: settings.paymentApiKey);
  late bool _liveMode = settings.paymentLiveMode;
  bool _testingPayment = false;

  // Supabase Cloud Sync
  late final _supaUrlCtrl = TextEditingController(text: settings.supabaseUrl);
  late final _supaKeyCtrl =
      TextEditingController(text: settings.supabaseAnonKey);
  late bool _supaAutoSync = settings.supabaseAutoSync;
  bool _syncingCloud = false;

  final _smsPresets = const [
    'BulkSMSBD',
    'GP SMS Gateway',
    'Robi SMS Gateway',
    'Greenweb BD',
    'Custom Provider',
  ];

  final _gateways = const ['SSLCommerz', 'bKash', 'Nagad'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -------------------------------------------------------------
          // 1. COACHING CENTER INFO
          // -------------------------------------------------------------
          _sectionHeader('Coaching Center Info'),
          TextField(
            controller: _centerNameCtrl,
            decoration: const InputDecoration(labelText: 'Center Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _centerPhoneCtrl,
            decoration: const InputDecoration(labelText: 'Center Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _centerAddressCtrl,
            decoration: const InputDecoration(labelText: 'Center Address'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await settings.saveCenterInfo(
                name: _centerNameCtrl.text.trim(),
                phone: _centerPhoneCtrl.text.trim(),
                address: _centerAddressCtrl.text.trim(),
              );
              _toast('Center info saved successfully');
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Center Info'),
          ),
          const Divider(height: 36),

          // -------------------------------------------------------------
          // 2. SMS GATEWAY CONFIGURATION
          // -------------------------------------------------------------
          _sectionHeader(
            'SMS Gateway (GP, Robi, BulkSMSBD, Greenweb)',
          ),
          const Text(
            'Select your provider preset or enter custom HTTP API URL with placeholders {phone}, {message}, {apikey}, {senderid}.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _smsPresets.contains(_smsPreset)
                ? _smsPreset
                : 'Custom Provider',
            decoration: const InputDecoration(labelText: 'Provider Preset'),
            items: _smsPresets
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _smsPreset = v;
                  final presetUrl = SmsService.getPresetUrl(v);
                  if (presetUrl.isNotEmpty) {
                    _smsUrlCtrl.text = presetUrl;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _smsUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'API URL Template',
              hintText:
                  'http://bulksmsbd.net/api/smsapi?api_key={apikey}&number={phone}&message={message}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _smsKeyCtrl,
            decoration: const InputDecoration(labelText: 'API Key / Token'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _smsSenderCtrl,
            decoration: const InputDecoration(
              labelText: 'Sender ID / Masking (optional)',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await settings.saveSmsSettings(
                      providerName: _smsPreset,
                      apiUrl: _smsUrlCtrl.text.trim(),
                      apiKey: _smsKeyCtrl.text.trim(),
                      senderId: _smsSenderCtrl.text.trim(),
                    );
                    _toast('SMS Settings Saved');
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save SMS Config'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _testingSms ? null : _openTestSmsDialog,
                icon: const Icon(Icons.send_to_mobile),
                label: const Text('Test SMS'),
              ),
            ],
          ),
          const Divider(height: 36),

          // -------------------------------------------------------------
          // 3. PAYMENT GATEWAY (SANDBOX READY)
          // -------------------------------------------------------------
          _sectionHeader('Payment Gateway (SSLCommerz / bKash / Nagad)'),
          const Text(
            'Pre-configured Sandbox endpoints ready for testing. Enable Live Mode with real merchant store credentials when launching.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gateways.contains(_paymentGateway)
                ? _paymentGateway
                : 'SSLCommerz',
            decoration: const InputDecoration(labelText: 'Gateway Provider'),
            items: _gateways
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) =>
                setState(() => _paymentGateway = v ?? _paymentGateway),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeIdCtrl,
            decoration: const InputDecoration(
              labelText: 'Store ID / Merchant ID (Required for Live)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            decoration: const InputDecoration(
              labelText: 'API Key / Secret (Required for Live)',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _liveMode,
            onChanged: (v) => setState(() => _liveMode = v),
            title: const Text('Live Mode'),
            subtitle: Text(
              _liveMode
                  ? 'Active: Real transactions enabled'
                  : 'Active: Sandbox Mode (Simulated transactions)',
              style: TextStyle(
                color: _liveMode ? kAccentRed : kAccentGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await settings.savePaymentSettings(
                      gateway: _paymentGateway,
                      storeId: _storeIdCtrl.text.trim(),
                      apiKey: _apiKeyCtrl.text.trim(),
                      liveMode: _liveMode,
                    );
                    _toast('Payment Settings Saved');
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Payment Config'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _testingPayment ? null : _runTestPayment,
                icon: const Icon(Icons.payment),
                label: const Text('Test Sandbox'),
              ),
            ],
          ),
          const Divider(height: 36),

          // -------------------------------------------------------------
          // 4. SUPABASE CLOUD BACKUP & MULTI-DEVICE SYNC
          // -------------------------------------------------------------
          _sectionHeader('Supabase Cloud Backup & Multi-Device Sync'),
          const Text(
            'Plug-in Supabase Cloud Architecture. Local-first Hive data remains primary; backup or restore anytime.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _supaUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'Supabase Project URL',
              hintText: 'https://xyzcompany.supabase.co',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _supaKeyCtrl,
            decoration: const InputDecoration(
              labelText: 'Supabase Anon / Public Key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _supaAutoSync,
            onChanged: (v) => setState(() => _supaAutoSync = v),
            title: const Text('Auto Cloud Sync'),
            subtitle: const Text('Automatically backup data on modifications'),
            contentPadding: EdgeInsets.zero,
          ),
          if (settings.lastSyncTimestamp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Last Cloud Sync: ${settings.lastSyncTimestamp}',
                style: const TextStyle(fontSize: 12, color: kPrimary),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () async {
              await settings.saveSupabaseSettings(
                url: _supaUrlCtrl.text.trim(),
                anonKey: _supaKeyCtrl.text.trim(),
                autoSync: _supaAutoSync,
              );
              _toast('Supabase Settings Saved');
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Supabase Config'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncingCloud ? null : _backupToCloud,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Backup Now'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncingCloud ? null : _restoreFromCloud,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Restore Cloud'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Section Header Builder
  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kPrimary,
          ),
        ),
      );

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: kAccentGreen),
    );
  }

  // Test SMS Dialog
  void _openTestSmsDialog() {
    final phoneCtrl = TextEditingController(text: settings.centerPhone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Test SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sends a sample SMS using the currently saved SMS Gateway API URL & Key.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Recipient Phone Number',
                hintText: '01712345678',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _testingSms = true);
              final smsService = SmsService(settings);
              final result =
                  await smsService.sendTestSms(phoneCtrl.text.trim());
              setState(() => _testingSms = false);

              if (mounted) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(
                        result.success ? 'SMS Sent Success' : 'SMS Test Failed'),
                    content: Text(result.message),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      )
                    ],
                  ),
                );
              }
            },
            child: const Text('Send Test'),
          ),
        ],
      ),
    );
  }

  // Test Payment Gateway Sandbox
  Future<void> _runTestPayment() async {
    setState(() => _testingPayment = true);
    final gatewayService = PaymentGatewayService(settings);
    final result = await gatewayService.testGatewayConnection();
    setState(() => _testingPayment = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(result.success
              ? '${settings.paymentGateway} Sandbox Ready'
              : 'Payment Error'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Supabase Backup
  Future<void> _backupToCloud() async {
    setState(() => _syncingCloud = true);
    final syncService = SupabaseSyncService(settings);
    final result = await syncService.backupToCloud();
    setState(() => _syncingCloud = false);

    if (mounted) {
      _toast(result.message);
    }
  }

  // Supabase Restore
  Future<void> _restoreFromCloud() async {
    setState(() => _syncingCloud = true);
    final syncService = SupabaseSyncService(settings);
    final result = await syncService.restoreFromCloud();
    setState(() => _syncingCloud = false);

    if (mounted) {
      _toast(result.message);
    }
  }
}
