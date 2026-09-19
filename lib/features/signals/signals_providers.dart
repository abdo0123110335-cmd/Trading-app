import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';

/// The symbols scanned before the full Screener (Phase 5) exists. Once
/// Watchlists/Screener land, this becomes "scan the active watchlist or
/// all Spot pairs" instead of a fixed list.
const defaultScanSymbols = ['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT'];

const defaultScanTimeframe = '1h';

/// Runs the Signal Engine (Strategy + Score + SMC) for each default scan
/// symbol and returns results sorted by score, highest first — real BUY/
/// HOLD/EXIT output, not placeholder data.
final signalScanProvider = FutureProvider.autoDispose<List<SignalResult>>((ref) async {
  final marketData = ref.watch(marketDataManagerProvider);
  final strategyRepo = ref.watch(strategyRepositoryProvider);
  final config = await strategyRepo.getDefaultStrategy();

  final results = <SignalResult>[];
  for (final symbol in defaultScanSymbols) {
    final candlesResult = await marketData.fetchCandlesSnapshot(
      symbol,
      defaultScanTimeframe,
      limit: 200,
    );
    candlesResult.when(
      ok: (candles) {
        if (candles.length < 60) return; // not enough history for filters yet
        results.add(generateSignal(symbol, defaultScanTimeframe, candles, config));
      },
      err: (_) {},
    );
  }

  results.sort((a, b) => b.score.compareTo(a.score));
  return results;
});
