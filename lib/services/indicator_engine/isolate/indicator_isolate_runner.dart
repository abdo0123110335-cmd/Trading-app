import 'package:flutter/foundation.dart' show compute;

import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_engine.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_settings.dart';

/// One symbol's worth of work for the batch runner: which candles to
/// analyze and which indicators to compute over them.
class IndicatorBatchJob {
  const IndicatorBatchJob({
    required this.symbol,
    required this.candles,
    required this.requests,
  });

  final String symbol;
  final List<Candle> candles;
  final List<IndicatorRequest> requests;
}

class IndicatorRequest {
  const IndicatorRequest(this.type, this.settings);
  final IndicatorType type;
  final IndicatorSettings settings;
}

/// Per-symbol results: indicator type → its [IndicatorResult].
class IndicatorBatchResult {
  const IndicatorBatchResult(this.symbol, this.results);
  final String symbol;
  final Map<IndicatorType, IndicatorResult> results;
}

/// Runs [computeIndicator] for every job/request pair on a background
/// isolate via Flutter's `compute()`, keeping the UI thread free while the
/// Screener/Scanner evaluate potentially hundreds of Spot pairs at once.
///
/// This is intentionally a single isolate spawn for the whole batch
/// (rather than one per symbol) — spawning an isolate per symbol would
/// itself become the bottleneck given Binance Spot lists 1000+ pairs.
Future<List<IndicatorBatchResult>> runIndicatorBatchInIsolate(
  List<IndicatorBatchJob> jobs,
) {
  return compute(_runBatch, jobs);
}

List<IndicatorBatchResult> _runBatch(List<IndicatorBatchJob> jobs) {
  final out = <IndicatorBatchResult>[];
  for (final job in jobs) {
    final resultsForSymbol = <IndicatorType, IndicatorResult>{};
    for (final req in job.requests) {
      resultsForSymbol[req.type] = computeIndicator(req.type, job.candles, req.settings);
    }
    out.add(IndicatorBatchResult(job.symbol, resultsForSymbol));
  }
  return out;
}
