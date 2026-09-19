import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/services/trading_engine/risk_manager.dart';

final _riskConfigProvider = FutureProvider.autoDispose<RiskConfig>((ref) {
  return ref.watch(riskManagerProvider).getConfig();
});

class RiskManagementScreen extends ConsumerWidget {
  const RiskManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(_riskConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Risk Management')),
      body: configAsync.when(
        data: (config) => _RiskForm(config: config),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}

class _RiskForm extends ConsumerStatefulWidget {
  const _RiskForm({required this.config});
  final RiskConfig config;

  @override
  ConsumerState<_RiskForm> createState() => _RiskFormState();
}

class _RiskFormState extends ConsumerState<_RiskForm> {
  late RiskConfig _config = widget.config;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_config.emergencyStopActive) const _EmergencyStopBanner(),
        _numberField(
          'Max Trade Amount (USDT)',
          _config.maxTradeAmountUsdt,
          (v) => setState(() => _config = _config.copyWith(maxTradeAmountUsdt: v)),
        ),
        _numberField(
          'Max Position Size (USDT)',
          _config.maxPositionSizeUsdt,
          (v) => setState(() => _config = _config.copyWith(maxPositionSizeUsdt: v)),
        ),
        _numberField(
          'Max Open Orders',
          _config.maxOpenOrders.toDouble(),
          (v) => setState(() => _config = _config.copyWith(maxOpenOrders: v.round())),
        ),
        _numberField(
          'Max Daily Risk (USDT)',
          _config.maxDailyRiskUsdt,
          (v) => setState(() => _config = _config.copyWith(maxDailyRiskUsdt: v)),
        ),
        _numberField(
          'Default Stop Loss (%)',
          _config.defaultStopLossPct,
          (v) => setState(() => _config = _config.copyWith(defaultStopLossPct: v)),
        ),
        _numberField(
          'Default Take Profit (%)',
          _config.defaultTakeProfitPct,
          (v) => setState(() => _config = _config.copyWith(defaultTakeProfitPct: v)),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Risk Settings'),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: MarketColors.bearish),
            icon: const Icon(Icons.dangerous_outlined),
            label: Text(_config.emergencyStopActive ? 'EMERGENCY STOP ACTIVE' : 'EMERGENCY STOP'),
            onPressed: _config.emergencyStopActive ? _clearEmergencyStop : _confirmEmergencyStop,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Immediately blocks all new orders — including from active strategies '
          'or alerts — until you turn this back off. Existing open orders on '
          'Binance are not cancelled automatically.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }

  Widget _numberField(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value == value.roundToDouble() ? value.round().toString() : '$value',
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (text) {
          final parsed = double.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(riskManagerProvider).saveConfig(_config);
    setState(() => _saving = false);
    ref.invalidate(_riskConfigProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risk settings saved')),
      );
    }
  }

  Future<void> _confirmEmergencyStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('Activate Emergency Stop?'),
        content: const Text(
          'This blocks every new order from this app immediately. You can turn '
          'it back off at any time from this screen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MarketColors.bearish),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('EMERGENCY STOP'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(riskManagerProvider).setEmergencyStop(true);
      setState(() => _config = _config.copyWith(emergencyStopActive: true));
    }
  }

  Future<void> _clearEmergencyStop() async {
    await ref.read(riskManagerProvider).setEmergencyStop(false);
    setState(() => _config = _config.copyWith(emergencyStopActive: false));
  }
}

class _EmergencyStopBanner extends StatelessWidget {
  const _EmergencyStopBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketColors.bearish.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MarketColors.bearish),
      ),
      child: const Row(
        children: [
          Icon(Icons.dangerous_outlined, color: MarketColors.bearish),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Emergency Stop is ACTIVE. No new orders can be placed.',
              style: TextStyle(color: MarketColors.bearish, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
