import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';

final _connectionStateProvider = FutureProvider.autoDispose((ref) async {
  final store = ref.watch(secureCredentialsStoreProvider);
  return (
    hasCredentials: await store.hasCredentials(),
    maskedKey: await store.readMaskedApiKey(),
    liveTradingEnabled: await store.isLiveTradingEnabled(),
    connectedAt: await store.readConnectedAt(),
  );
});

class BinanceConnectionScreen extends ConsumerWidget {
  const BinanceConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(_connectionStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Binance Connection')),
      body: stateAsync.when(
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!state.hasCredentials)
              _ConnectForm(onSaved: () => ref.invalidate(_connectionStateProvider))
            else
              _ConnectedPanel(
                maskedKey: state.maskedKey ?? '••••••••',
                connectedAt: state.connectedAt,
                liveTradingEnabled: state.liveTradingEnabled,
                onDisconnect: () => _disconnect(context, ref),
                onToggleLiveTrading: (v) => _toggleLiveTrading(context, ref, v),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('Disconnect Binance account?'),
        content: const Text(
          'This permanently removes your saved API key and secret from this '
          'device and turns off Live Spot Trading. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect', style: TextStyle(color: MarketColors.bearish)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(secureCredentialsStoreProvider).clearCredentials();
      ref.invalidate(_connectionStateProvider);
    }
  }

  Future<void> _toggleLiveTrading(BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: MarketColors.surfaceDarkElevated,
          title: const Text('Enable Live Spot Trading?'),
          content: const Text(
            'Orders placed from this app will use REAL funds in your Binance '
            'account. Spot only — no leverage, no margin, no short selling. '
            'Every order will still ask you to confirm before it is sent.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(secureCredentialsStoreProvider).setLiveTradingEnabled(enable);
    ref.invalidate(_connectionStateProvider);
  }
}

class _ConnectForm extends ConsumerStatefulWidget {
  const _ConnectForm({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_ConnectForm> createState() => _ConnectFormState();
}

class _ConnectFormState extends ConsumerState<_ConnectForm> {
  final _keyController = TextEditingController();
  final _secretController = TextEditingController();
  bool _obscureSecret = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SecurityNotice(),
        const SizedBox(height: 20),
        TextField(
          controller: _keyController,
          decoration: const InputDecoration(labelText: 'API Key'),
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _secretController,
          decoration: InputDecoration(
            labelText: 'API Secret',
            suffixIcon: IconButton(
              icon: Icon(_obscureSecret ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
            ),
          ),
          obscureText: _obscureSecret,
          autocorrect: false,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    final secret = _secretController.text.trim();
    if (key.isEmpty || secret.isEmpty) return;

    setState(() => _saving = true);
    await ref
        .read(secureCredentialsStoreProvider)
        .saveCredentials(apiKey: key, apiSecret: secret);
    // Clear the fields from memory/widget state immediately after saving —
    // the secret must not linger in a TextEditingController any longer
    // than necessary.
    _keyController.clear();
    _secretController.clear();
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _secretController.dispose();
    super.dispose();
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: MarketColors.bullish, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your API key and secret are encrypted with Android Keystore on this '
                'device only. They are never sent anywhere except directly to Binance, '
                'never logged, and never leave this device.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedPanel extends ConsumerWidget {
  const _ConnectedPanel({
    required this.maskedKey,
    required this.connectedAt,
    required this.liveTradingEnabled,
    required this.onDisconnect,
    required this.onToggleLiveTrading,
  });

  final String maskedKey;
  final DateTime? connectedAt;
  final bool liveTradingEnabled;
  final VoidCallback onDisconnect;
  final ValueChanged<bool> onToggleLiveTrading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(_apiPermissionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: MarketColors.bullish),
            title: Text(maskedKey),
            subtitle: Text(connectedAt == null ? 'Connected' : 'Connected ${connectedAt.toString().split('.').first}'),
          ),
        ),
        const SizedBox(height: 8),
        permissionsAsync.when(
          data: (canTrade) => _PermissionCard(canTrade: canTrade),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Could not check API key permissions: $e'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            title: const Text('Enable Live Spot Trading'),
            subtitle: const Text('OFF by default. Real orders, Spot only — no leverage, no shorts.'),
            value: liveTradingEnabled,
            onChanged: onToggleLiveTrading,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.link_off, color: MarketColors.bearish),
          label: const Text('Disconnect', style: TextStyle(color: MarketColors.bearish)),
          onPressed: onDisconnect,
        ),
      ],
    );
  }
}

final _apiPermissionsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final client = ref.watch(binanceRestClientProvider);
  final result = await client.getApiKeyPermissions();
  return result.when(
    ok: (data) => data['enableSpotAndMarginTrading'] as bool? ?? false,
    err: (e) => throw e,
  );
});

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.canTrade});
  final bool canTrade;

  @override
  Widget build(BuildContext context) {
    if (!canTrade) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.block, color: MarketColors.neutral),
              SizedBox(width: 10),
              Expanded(child: Text('Trading Disabled — this API key has no trading permission.')),
            ],
          ),
        ),
      );
    }
    return Card(
      color: MarketColors.warning.withValues(alpha: 0.08),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: MarketColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This API key CAN place real trades. Keep it secret — anyone with '
                'this key and secret could trade on your Binance account.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
