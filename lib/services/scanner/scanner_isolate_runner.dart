import 'package:flutter/foundation.dart' show compute;

import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/atr.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';
import 'package:binance_spot_pro/services/scanner/scan_models.dart';
import 'package:binance_spot_pro/services/scanner/setup_detector.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';
import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

class ScanJob {
  const ScanJob({
    required this.symbol,
    required this.candles,
    required this.priceChangePercent,
  });
  final String symbol;
  final List<Candle> candles;
  final double priceChangePercent;
}

class _ScanBatchInput {
  const _ScanBatchInput(this.jobs, this.config, this.timeframe);
  final List<ScanJob> jobs;
  final StrategyConfig config;
  final String timeframe;
}

/// Runs the full Strategy → Score → SMC → Signal → setup-tag pipeline for
/// every job on one background isolate. This is the expensive part of
/// scanning hundreds of Spot pairs (candle *fetching* stays on the main
/// isolate since it's just network I/O) — keeping it off the UI thread is
/// what makes scanning the whole market not stutter the app, per the
/// spec's performance requirement.
Future<List<ScanResult>> runScanInIsolate(
  List<ScanJob> jobs,
  StrategyConfig config,
  String timeframe,
) {
  return compute(_runScanBatch, _ScanBatchInput(jobs, config, timeframe));
}

List<ScanResult> _runScanBatch(_ScanBatchInput input) {
  final out = <ScanResult>[];
  for (final job in input.jobs) {
    if (job.candles.length < 60) continue; // not enough history for filters

    final evaluation = evaluateRsiEmaStrategy(job.candles, input.config);
    final signal = generateSignal(job.symbol, input.timeframe, job.candles, input.config);
    final tags = detectSetupTags(job.candles, evaluation, signal);

    final volumes = job.candles.volumes();
    final volSma = sma(volumes, 20);
    final relativeVolume = (volSma.isNotEmpty && volSma.last != null && volSma.last! > 0)
        ? volumes.last / volSma.last!
        : null;

    final atrSeries = atrFromOhlc(
      job.candles.highs(),
      job.candles.lows(),
      job.candles.closes(),
      length: 14,
    );
    final atr = atrSeries.isNotEmpty ? atrSeries.last : null;

    out.add(
      ScanResult(
        symbol: job.symbol,
        signal: signal,
        tags: tags,
        rsi: evaluation.rsiValue,
        relativeVolume: relativeVolume,
        atr: atr,
        priceChangePercent: job.priceChangePercent,
      ),
    );
  }
  return out;
}
