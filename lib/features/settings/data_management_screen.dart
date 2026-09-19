import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/data/repositories/candle_repository.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionTile(
            icon: Icons.cached,
            title: 'Clear Cache',
            subtitle: 'Removes cached candle history. Fresh data is re-downloaded as needed.',
            onTap: () => _clearCache(context, ref),
          ),
          _ActionTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Delete Local Data',
            subtitle:
                'Removes watchlists, alerts, drawings, signals and trade history from this '
                'device. Does NOT remove your Binance API key — that requires a separate '
                'confirmation from Binance Connection.',
            destructive: true,
            onTap: () => _deleteLocalData(context, ref),
          ),
          const Divider(height: 32),
          _ActionTile(
            icon: Icons.upload_outlined,
            title: 'Export Settings',
            subtitle:
                'Copies your strategy and risk settings as JSON to the clipboard. '
                'Never includes API keys or secrets.',
            onTap: () => _exportSettings(context, ref),
          ),
          _ActionTile(
            icon: Icons.download_outlined,
            title: 'Import Settings',
            subtitle: 'Paste previously exported settings JSON to restore them.',
            onTap: () => _importSettings(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      'Clear cache?',
      'This removes cached candle history only.',
    );
    if (confirmed != true) return;
    await CandleRepository(ref.read(appDatabaseProvider)).deleteAll();
    if (context.mounted) _snack(context, 'Cache cleared');
  }

  Future<void> _deleteLocalData(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      'Delete all local data?',
      'This permanently removes watchlists, alerts, drawings, signals and trade history from '
          'this device. Your Binance API key is not affected. This cannot be undone.',
      destructive: true,
    );
    if (confirmed != true) return;

    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      await db.delete(db.watchlistSymbols).go();
      await db.delete(db.watchlists).go();
      await db.delete(db.alertHistory).go();
      await db.delete(db.alerts).go();
      await db.delete(db.drawings).go();
      await db.delete(db.signals).go();
      await db.delete(db.trades).go();
      await db.delete(db.orders).go();
      await db.delete(db.portfolio).go();
      await db.delete(db.candles).go();
    });
    if (context.mounted) _snack(context, 'Local data deleted');
  }

  Future<void> _exportSettings(BuildContext context, WidgetRef ref) async {
    final config = await ref.read(strategyRepositoryProvider).getDefaultStrategy();
    final risk = await ref.read(riskManagerProvider).getConfig();
    final json = jsonEncode({
      'strategy': config.toSettingsMap(),
      'risk': {
        'maxTradeAmountUsdt': risk.maxTradeAmountUsdt,
        'maxPositionSizeUsdt': risk.maxPositionSizeUsdt,
        'maxOpenOrders': risk.maxOpenOrders,
        'maxDailyRiskUsdt': risk.maxDailyRiskUsdt,
        'defaultStopLossPct': risk.defaultStopLossPct,
        'defaultTakeProfitPct': risk.defaultTakeProfitPct,
      },
    });
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) _snack(context, 'Settings copied to clipboard');
  }

  Future<void> _importSettings(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('Import Settings'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Paste exported settings JSON here'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (json == null || json.trim().isEmpty) return;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final strategyMap = (data['strategy'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, '$v'),
      );
      if (strategyMap != null) {
        final current = await ref.read(strategyRepositoryProvider).getDefaultStrategy();
        final imported = current.copyWith(
          rsiLength: int.tryParse(strategyMap['rsi_length'] ?? ''),
          rsiOversold: double.tryParse(strategyMap['rsi_oversold'] ?? ''),
          rsiOverbought: double.tryParse(strategyMap['rsi_overbought'] ?? ''),
          minBuyScore: int.tryParse(strategyMap['min_buy_score'] ?? ''),
        );
        await ref.read(strategyRepositoryProvider).saveStrategy(imported);
      }
      if (context.mounted) _snack(context, 'Settings imported');
    } catch (e) {
      if (context.mounted) _snack(context, 'Import failed: invalid JSON');
    }
  }

  Future<bool?> _confirm(
    BuildContext context,
    String title,
    String message, {
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: TextStyle(color: destructive ? MarketColors.bearish : null)),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: destructive ? MarketColors.bearish : null),
        title: Text(title, style: TextStyle(color: destructive ? MarketColors.bearish : null)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}
