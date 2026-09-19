import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/features/signals/signals_providers.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';

class SignalsScreen extends ConsumerWidget {
  const SignalsScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(signalScanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signals'),
        leading: onMenuPressed == null
            ? null
            : IconButton(icon: const Icon(Icons.menu), onPressed: onMenuPressed),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(signalScanProvider),
          ),
        ],
      ),
      body: scan.when(
        data: (signals) {
          if (signals.isEmpty) {
            return const Center(child: Text('Not enough history to generate signals yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(signalScanProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'RSI(6) + EMA strategy · 1h · min BUY score 75. '
                    'Score reflects how many bullish conditions currently line up — '
                    'not a guarantee of profit.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                for (final s in signals) _SignalCard(signal: s),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});
  final SignalResult signal;

  Color get _typeColor {
    switch (signal.type) {
      case SignalType.buy:
        return MarketColors.bullish;
      case SignalType.exit:
        return MarketColors.bearish;
      case SignalType.hold:
        return MarketColors.neutral;
    }
  }

  String get _typeLabel {
    switch (signal.type) {
      case SignalType.buy:
        return 'BUY';
      case SignalType.exit:
        return 'EXIT';
      case SignalType.hold:
        return 'HOLD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat('#,##0.00########');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _typeLabel,
                    style: TextStyle(color: _typeColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(signal.symbol, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Text('${signal.score}/100', style: TextStyle(color: _scoreColor(signal.score))),
              ],
            ),
            const SizedBox(height: 6),
            Text('Price ${priceFmt.format(signal.price)} · ${signal.timeframe}'),
            if (signal.reasons.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final r in signal.reasons)
                    Chip(
                      label: Text(r, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: MarketColors.surfaceDark,
                      side: const BorderSide(color: MarketColors.borderDark),
                    ),
                ],
              ),
            ],
            if (signal.type == SignalType.buy) ...[
              const Divider(height: 20),
              _levelsRow(priceFmt),
            ],
          ],
        ),
      ),
    );
  }

  Widget _levelsRow(NumberFormat fmt) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
      children: [
        TableRow(
          children: [
            _levelCell('Entry', '${fmt.format(signal.entryLow)} – ${fmt.format(signal.entryHigh)}'),
            _levelCell('Invalidation', fmt.format(signal.invalidation), color: MarketColors.bearish),
            _levelCell('TP1 / TP2', '${fmt.format(signal.tp1)} / ${fmt.format(signal.tp2)}', color: MarketColors.bullish),
          ],
        ),
      ],
    );
  }

  Widget _levelCell(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: MarketColors.neutral)),
          Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return MarketColors.bullish;
    if (score >= 50) return MarketColors.warning;
    return MarketColors.neutral;
  }
}
