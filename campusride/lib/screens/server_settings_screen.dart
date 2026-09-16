import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../widgets/common_widgets.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _controller;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      showAppSnack(context, 'Enter a valid server URL.', error: true);
      return;
    }
    ApiConfig.setBaseUrl(url);
    // Clear any stale session so the new server can be tested fresh.
    final client = ApiClient.instance;
    await client.clearTokens();
    if (!mounted) return;
    showAppSnack(context, 'Server updated. Please sign in again.');
    Navigator.of(context).pop(true);
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final http = Uri.tryParse(ApiConfig.baseUrl);
    if (http == null) {
      setState(() => _testing = false);
      return;
    }
    try {
      await ApiClient.instance.get('/health');
      if (!mounted) return;
      setState(() => _testing = false);
      showAppSnack(context, 'Connected! ${ApiConfig.baseUrl} is reachable.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testing = false);
      showAppSnack(context, 'Connection failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Paste the base URL the app should talk to.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            'Local (iOS simulator):  http://localhost:3000/api/v1\n'
            'Android emulator:       http://10.0.2.2:3000/api/v1\n'
            'Real phone (ngrok):     the https URL printed by the backend.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API Base URL',
              prefixIcon: Icon(Icons.dns_outlined),
              hintText: 'https://xxxx.ngrok-free.app/api/v1',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('Test Connection'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save & Reconnect'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Current URL', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(ApiConfig.baseUrl, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}