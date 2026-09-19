import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

final _strategyConfigProvider = FutureProvider.autoDispose<StrategyConfig>((ref) {
  return ref.watch(strategyRepositoryProvider).getDefaultStrategy();
});

class StrategySettingsScreen extends ConsumerWidget {
  const StrategySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(_strategyConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Strategy Settings')),
      body: configAsync.when(
        data: (config) => _StrategyForm(config: config),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}

class _StrategyForm extends ConsumerStatefulWidget {
  const _StrategyForm({required this.config});
  final StrategyConfig config;

  @override
  ConsumerState<_StrategyForm> createState() => _StrategyFormState();
}

class _StrategyFormState extends ConsumerState<_StrategyForm> {
  late StrategyConfig _config = widget.config;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('RSI + EMA Strategy', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _numField('RSI Length', _config.rsiLength.toDouble(), (v) => _config = _config.copyWith(rsiLength: v.round())),
        _numField('Oversold', _config.rsiOversold, (v) => _config = _config.copyWith(rsiOversold: v)),
        _numField('Overbought', _config.rsiOverbought, (v) => _config = _config.copyWith(rsiOverbought: v)),
        _numField('Minimum BUY Score', _config.minBuyScore.toDouble(), (v) => _config = _config.copyWith(minBuyScore: v.round())),
        const Divider(height: 32),
        Text('Optional Filters', style: Theme.of(context).textTheme.titleMedium),
        _filterSwitch('EMA Filter', _config.filterEmaEnabled, (v) => _config = _config.copyWith(filterEmaEnabled: v)),
        _filterSwitch('Volume Filter', _config.filterVolumeEnabled, (v) => _config = _config.copyWith(filterVolumeEnabled: v)),
        _filterSwitch('MACD Filter', _config.filterMacdEnabled, (v) => _config = _config.copyWith(filterMacdEnabled: v)),
        _filterSwitch('Trend Filter', _config.filterTrendEnabled, (v) => _config = _config.copyWith(filterTrendEnabled: v)),
        _filterSwitch('Support Filter', _config.filterSupportEnabled, (v) => _config = _config.copyWith(filterSupportEnabled: v)),
        _filterSwitch('SMC Filter', _config.filterSmcEnabled, (v) => _config = _config.copyWith(filterSmcEnabled: v)),
        const Divider(height: 32),
        Text('Score Weights', style: Theme.of(context).textTheme.titleMedium),
        _numField('RSI Weight', _config.weightRsi, (v) => _config = _config.copyWith(weightRsi: v)),
        _numField('EMA Weight', _config.weightEma, (v) => _config = _config.copyWith(weightEma: v)),
        _numField('MACD Weight', _config.weightMacd, (v) => _config = _config.copyWith(weightMacd: v)),
        _numField('Volume Weight', _config.weightVolume, (v) => _config = _config.copyWith(weightVolume: v)),
        _numField('Trend Weight', _config.weightTrend, (v) => _config = _config.copyWith(weightTrend: v)),
        _numField('SMC Weight', _config.weightSmc, (v) => _config = _config.copyWith(weightSmc: v)),
        _numField('Support Weight', _config.weightSupport, (v) => _config = _config.copyWith(weightSupport: v)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Strategy'),
        ),
      ],
    );
  }

  Widget _numField(String label, double value, void Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('$label-${widget.config.strategyId}'),
        initialValue: value == value.roundToDouble() ? value.round().toString() : '$value',
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (text) {
          final parsed = double.tryParse(text);
          if (parsed != null) setState(() => onChanged(parsed));
        },
      ),
    );
  }

  Widget _filterSwitch(String label, bool value, void Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(strategyRepositoryProvider).saveStrategy(_config);
    setState(() => _saving = false);
    ref.invalidate(_strategyConfigProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Strategy saved')));
    }
  }
}
