import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/data/models/ticker_24hr.dart';
import 'package:binance_spot_pro/features/signals/signals_providers.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_engine.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_settings.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';

const _homeOverviewSymbols = ['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT'];

final _homeOverviewProvider = FutureProvider.autoDispose<List<Ticker24hr>>((
  ref,
) async {
  final repo = ref.watch(marketRepositoryProvider);
  final result = await repo.getTickers24hr();
  return result.when(
    ok: (all) => all.where((t) => _homeOverviewSymbols.contains(t.symbol)).toList()
      ..sort(
        (a, b) => _homeOverviewSymbols
            .indexOf(a.symbol)
            .compareTo(_homeOverviewSymbols.indexOf(b.symbol)),
      ),
    err: (e) => throw e,
  );
});

/// Live RSI(6) on the 1h timeframe for each overview symbol — real
/// indicator output from the Phase 2 Indicator Engine, not a placeholder.
final _homeRsiProvider = FutureProvider.autoDispose<Map<String, double?>>((
  ref,
) async {
  final manager = ref.watch(marketDataManagerProvider);
  final settings = IndicatorSettings.defaultsFor(IndicatorType.rsi);
  final out = <String, double?>{};
  for (final symbol in _homeOverviewSymbols) {
    final result = await manager.fetchCandlesSnapshot(symbol, '1h', limit: 100);
    result.when(
      ok: (candles) {
        final r = computeIndicator(IndicatorType.rsi, candles, settings);
        out[symbol] = r.latest('value');
      },
      err: (_) => out[symbol] = null,
    );
  }
  return out;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(_homeOverviewProvider);
    final rsiMap = ref.watch(_homeRsiProvider);
    final signalScan = ref.watch(signalScanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Binance Spot Pro'),
        leading: onMenuPressed == null
            ? null
            : IconButton(icon: const Icon(Icons.menu), onPressed: onMenuPressed),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_homeOverviewProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Market Overview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            overview.when(
              data: (tickers) => _OverviewList(
                tickers: tickers,
                rsiMap: rsiMap.asData?.value ?? const {},
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => _ErrorCard(message: '$e'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('Top Opportunities', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            signalScan.when(
              data: (signals) => _TopOpportunitiesList(signals: signals),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => _ErrorCard(message: '$e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewList extends StatelessWidget {
  const _OverviewList({required this.tickers, required this.rsiMap});
  final List<Ticker24hr> tickers;
  final Map<String, double?> rsiMap;

  @override
  Widget build(BuildContext context) {
    if (tickers.isEmpty) {
      return const _ErrorCard(message: 'No market data available right now.');
    }
    final priceFmt = NumberFormat('#,##0.00##');
    final volFmt = NumberFormat.compact();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final t in tickers) ...[
            ListTile(
              title: Text(t.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Vol ${volFmt.format(t.quoteVolume)} USDT'
                '${rsiMap[t.symbol] != null ? '  ·  RSI(6) 1h ${rsiMap[t.symbol]!.toStringAsFixed(1)}' : ''}',
              ),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(priceFmt.format(t.lastPrice)),
                  Text(
                    '${t.isBullish ? '+' : ''}${t.priceChangePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: t.isBullish ? MarketColors.bullish : MarketColors.bearish,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (t != tickers.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

/// Ranked output of the real Strategy + Score + SMC Signal Engine
/// (Phase 4), highest score first. Only BUY/EXIT are surfaced here —
/// HOLD entries are visible on the full Signals tab but don't belong in
/// an "opportunities" list. No score is described as a guarantee.
class _TopOpportunitiesList extends StatelessWidget {
  const _TopOpportunitiesList({required this.signals});
  final List<SignalResult> signals;

  @override
  Widget build(BuildContext context) {
    final actionable = signals.where((s) => s.type != SignalType.hold).toList();
    if (actionable.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No BUY or EXIT setups right now on the scanned symbols — '
            'everything is reading HOLD. See the Signals tab for full detail.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final s in actionable) ...[
            ListTile(
              leading: Container(
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (s.type == SignalType.buy ? MarketColors.bullish : MarketColors.bearish)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.type == SignalType.buy ? 'BUY' : 'EXIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: s.type == SignalType.buy ? MarketColors.bullish : MarketColors.bearish,
                  ),
                ),
              ),
              title: Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.reasons.isEmpty ? '1h' : s.reasons.first),
              trailing: Text('${s.score}/100', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (s != actionable.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: MarketColors.bearish),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
