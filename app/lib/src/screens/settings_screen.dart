import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;
  String _serverStatus = '-';
  String _lastRun = '-';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
        text: context.read<AppState>().baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final appState = context.read<AppState>();
    final api = appState.api;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await appState.setBaseUrl(_urlController.text);
      await api.health();
      final status = await api.status();
      final poller =
          status['poller'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testResult = 'Terhubung ke server.';
        _serverStatus = poller['status'] as String? ?? '-';
        _lastRun = poller['lastRun'] as String? ?? '-';
        _testing = false;
      });
      appState.startRealtime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testResult = 'Gagal terhubung: $e';
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final horizontal = Screen.horizontalPadding(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(horizontal, Screen.verticalPadding(context), horizontal, 32 + Screen.bottomInset(context)),
      children: [
        Text(
          'Pengaturan',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns_rounded, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text('Server Backend',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'URL server',
                    hintText: 'http://192.168.1.10:8080',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contoh: emulator Android gunakan http://10.0.2.2:8080, '
                  'perangkat fisik gunakan IP LAN server.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: Text(_testing ? 'Menghubungkan...' : 'Tes & Simpan'),
                      ),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _testOk
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: _testOk ? Colors.green : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_testResult!,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded),
            title: const Text('Mode Gelap'),
            subtitle: const Text('Nuansa gelap khas anime'),
            value: appState.darkMode,
            onChanged: (v) => appState.setDarkMode(v),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded,
                color: AppTheme.primary),
            title: const Text('Notifikasi Update'),
            subtitle: const Text('Kirim notifikasi saat anime yang dilacak '
                'mendapat episode atau status baru'),
            value: appState.notificationsEnabled,
            onChanged: (v) => appState.setNotificationsEnabled(v),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monitor_heart_rounded,
                        color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Text('Status Realtime',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                _StatusRow(label: 'Koneksi', value: appState.connected ? 'Terhubung' : 'Terputus'),
                _StatusRow(label: 'Poller', value: _serverStatus),
                _StatusRow(label: 'Terakhir scan', value: _lastRun),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final api = context.read<ApiClient>();
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await api.health();
                        final status = await api.status();
                        final poller = status['poller'] as Map<String, dynamic>? ?? {};
                        if (!mounted) return;
                        setState(() {
                          _serverStatus = poller['status'] as String? ?? '-';
                          _lastRun = poller['lastRun'] as String? ?? '-';
                        });
                        messenger.showSnackBar(
                            const SnackBar(content: Text('Status server dimuat.')));
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                            SnackBar(content: Text('Gagal: $e')));
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Muat ulang status'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text('Tentang',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Anime Tracker v1.0.0\n'
                  'Data anime dari AniList (GraphQL API).\n'
                  'App Flutter + Backend Go dengan update realtime via SSE.\n\n'
                  'Fitur: update rilis (TV/Movie/OVA/ONA), musim terkini, '
                  'pencarian + filter genre, dan notifikasi realtime untuk '
                  'anime yang dilacak.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
