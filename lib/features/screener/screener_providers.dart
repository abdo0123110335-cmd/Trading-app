import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/services/scanner/scan_models.dart';
import 'package:binance_spot_pro/services/scanner/scanner_service.dart';

enum ScreenerSort { score, volume, change, rsi }

class ScreenerParams {
  const ScreenerParams({
    this.source = ScanSource.allSpot,
    this.watchlistId,
    this.timeframe = '1h',
    this.sortBy = ScreenerSort.score,
    this.activeTags = const {},
  });

  final ScanSource source;
  final int? watchlistId;
  final String timeframe;
  final ScreenerSort sortBy;
  final Set<ScanSetupTag> activeTags;

  ScreenerParams copyWith({
    ScanSource? source,
    int? watchlistId,
    String? timeframe,
    ScreenerSort? sortBy,
    Set<ScanSetupTag>? activeTags,
  }) {
    return ScreenerParams(
      source: source ?? this.source,
      watchlistId: watchlistId ?? this.watchlistId,
      timeframe: timeframe ?? this.timeframe,
      sortBy: sortBy ?? this.sortBy,
      activeTags: activeTags ?? this.activeTags,
    );
  }
}

final screenerParamsProvider = StateProvider.autoDispose<ScreenerParams>(
  (ref) => const ScreenerParams(),
);

/// Runs a scan on demand (manual trigger via the Screener's "Scan" button)
/// rather than continuously in the background — continuous background
/// scanning is Settings > Background Monitoring (Phase 6), gated behind
/// an explicit opt-in precisely because of the battery cost of scanning
/// repeatedly without the user asking.
final screenerScanProvider = FutureProvider.autoDispose<List<ScanResult>>((ref) async {
  final params = ref.watch(screenerParamsProvider);
  final scanner = ref.watch(scannerServiceProvider);
  final strategyRepo = ref.watch(strategyRepositoryProvider);
  final config = await strategyRepo.getDefaultStrategy();

  final results = await scanner.scan(
    source: params.source,
    watchlistId: params.watchlistId,
    config: config,
    timeframe: params.timeframe,
  );

  final filtered = params.activeTags.isEmpty
      ? results
      : results.where((r) => params.activeTags.every(r.tags.contains)).toList();

  filtered.sort((a, b) {
    switch (params.sortBy) {
      case ScreenerSort.score:
        return b.signal.score.compareTo(a.signal.score);
      case ScreenerSort.volume:
        return (b.relativeVolume ?? 0).compareTo(a.relativeVolume ?? 0);
      case ScreenerSort.change:
        return b.priceChangePercent.compareTo(a.priceChangePercent);
      case ScreenerSort.rsi:
        return (a.rsi ?? 100).compareTo(b.rsi ?? 100);
    }
  });

  return filtered;
});
