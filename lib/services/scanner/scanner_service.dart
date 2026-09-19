import 'package:binance_spot_pro/data/repositories/watchlist_repository.dart';
import 'package:binance_spot_pro/data/models/ticker_24hr.dart';
import 'package:binance_spot_pro/data/repositories/market_repository.dart';
import 'package:binance_spot_pro/services/market_data/market_data_manager.dart';
import 'package:binance_spot_pro/services/scanner/scan_models.dart';
import 'package:binance_spot_pro/services/scanner/scanner_isolate_runner.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

enum ScanSource { allSpot, watchlist, favorites }

/// Orchestrates a full market scan without hammering Binance or draining
/// the battery/RAM:
///   * "All Spot" is capped to the top-volume [maxSymbols] pairs rather
///     than all 1000+ listed pairs — scanning literally everything on
///     every tap would be dozens of REST calls and a heavy isolate job
///     for very little extra signal quality over the most liquid pairs.
///   * Candle fetches are throttled to [concurrency] in flight at once,
///     with a short pause between batches, to stay well under Binance's
///     REST weight limits.
///   * The actual indicator/SMC/score computation runs on a background
///     isolate (see [runScanInIsolate]) so the UI thread never stalls.
class ScannerService {
  ScannerService({
    required MarketDataManager marketData,
    required MarketRepository marketRepository,
    required WatchlistRepository watchlistRepository,
  }) : _marketData = marketData,
       _marketRepo = marketRepository,
       _watchlistRepo = watchlistRepository;

  final MarketDataManager _marketData;
  final MarketRepository _marketRepo;
  final WatchlistRepository _watchlistRepo;

  Future<List<ScanResult>> scan({
    required ScanSource source,
    int? watchlistId,
    required StrategyConfig config,
    String timeframe = '1h',
    int maxSymbols = 60,
    int concurrency = 6,
  }) async {
    final tickers = await _fetchTickers();
    final symbols = await _resolveSymbols(source, watchlistId, maxSymbols, tickers);
    if (symbols.isEmpty) return [];

    final jobs = await _fetchCandlesThrottled(symbols, timeframe, tickers, concurrency);
    if (jobs.isEmpty) return [];

    return runScanInIsolate(jobs, config, timeframe);
  }

  Future<Map<String, Ticker24hr>> _fetchTickers() async {
    final result = await _marketRepo.getTickers24hr();
    return result.when(
      ok: (list) => {for (final t in list) t.symbol: t},
      err: (_) => {},
    );
  }

  Future<List<String>> _resolveSymbols(
    ScanSource source,
    int? watchlistId,
    int maxSymbols,
    Map<String, Ticker24hr> tickers,
  ) async {
    switch (source) {
      case ScanSource.watchlist:
        if (watchlistId == null) return [];
        return _watchlistRepo.getSymbols(watchlistId);

      case ScanSource.favorites:
        final id = await _watchlistRepo.getOrCreateFavoritesId();
        return _watchlistRepo.getSymbols(id);

      case ScanSource.allSpot:
        final symbolsResult = await _marketRepo.getTradableUsdtSymbols();
        final tradable = symbolsResult.when(
          ok: (rows) => rows.map((r) => r['symbol'] as String).toSet(),
          err: (_) => <String>{},
        );
        final ranked = tickers.values.where((t) => tradable.contains(t.symbol)).toList()
          ..sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
        return ranked.take(maxSymbols).map((t) => t.symbol).toList();
    }
  }

  Future<List<ScanJob>> _fetchCandlesThrottled(
    List<String> symbols,
    String timeframe,
    Map<String, Ticker24hr> tickers,
    int concurrency,
  ) async {
    final jobs = <ScanJob>[];
    for (var i = 0; i < symbols.length; i += concurrency) {
      final batch = symbols.skip(i).take(concurrency);
      final results = await Future.wait(
        batch.map((symbol) async {
          final result = await _marketData.fetchCandlesSnapshot(symbol, timeframe, limit: 200);
          return result.when(
            ok: (candles) => ScanJob(
              symbol: symbol,
              candles: candles,
              priceChangePercent: tickers[symbol]?.priceChangePercent ?? 0,
            ),
            err: (_) => null,
          );
        }),
      );
      jobs.addAll(results.whereType<ScanJob>());

      if (i + concurrency < symbols.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    return jobs;
  }
}
