import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/atr.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/macd.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/rsi.dart';
import 'package:binance_spot_pro/services/signal_engine/multi_timeframe_analyzer.dart';
import 'package:binance_spot_pro/services/signal_engine/score_calculator.dart';
import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

/// Builds the exact data payload sent to the AI provider. Every field
/// here comes from an engine already built in earlier phases — this
/// function computes nothing new and fabricates nothing. If a value
/// can't be computed (not enough candle history), it's simply omitted
/// from the payload rather than guessed at.
class AiAnalysisContext {
  const AiAnalysisContext({required this.symbol, required this.sections});
  final String symbol;

  /// Ordered "label: value" lines, kept as plain text rather than a
  /// nested JSON blob so a human can see exactly what was, and wasn't,
  /// sent to the AI provider.
  final List<String> sections;

  String toPromptText() {
    final buffer = StringBuffer();
    buffer.writeln('Symbol: $symbol (Binance Spot)');
    for (final line in sections) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }
}

AiAnalysisContext buildAiContext({
  required String symbol,
  required List<Candle> candles,
  required StrategyConfig config,
  Map<String, TrendReading>? multiTimeframe,
}) {
  final sections = <String>[];

  if (candles.length < 60) {
    sections.add('Data: insufficient candle history for reliable indicators.');
    return AiAnalysisContext(symbol: symbol, sections: sections);
  }

  final closes = candles.closes();
  final price = candles.last.close;
  sections.add('Price: $price');
  final lowestLow = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
  final highestHigh = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
  sections.add('Loaded window range: low $lowestLow, high $highestHigh');

  final rsiSeries = rsi(closes, config.rsiLength);
  if (rsiSeries.isNotEmpty && rsiSeries.last != null) {
    sections.add('RSI(${config.rsiLength}): ${rsiSeries.last!.toStringAsFixed(2)}');
  }

  final ema21Series = ema(closes, 21);
  final ema50Series = ema(closes, 50);
  final ema21 = ema21Series.isEmpty ? null : ema21Series.last;
  final ema50 = ema50Series.isEmpty ? null : ema50Series.last;
  if (ema21 != null) sections.add('EMA(21): ${ema21.toStringAsFixed(4)}');
  if (ema50 != null) sections.add('EMA(50): ${ema50.toStringAsFixed(4)}');

  final macdResult = macd(closes);
  if (macdResult.histogram.isNotEmpty && macdResult.histogram.last != null) {
    sections.add('MACD histogram: ${macdResult.histogram.last!.toStringAsFixed(4)}');
  }

  final atrSeries = atrFromOhlc(candles.highs(), candles.lows(), closes, length: 14);
  if (atrSeries.isNotEmpty && atrSeries.last != null) {
    sections.add('ATR(14): ${atrSeries.last!.toStringAsFixed(4)}');
  }

  final evaluation = evaluateRsiEmaStrategy(candles, config);
  final score = computeScore(evaluation, config);
  sections.add('Strategy Score (0-100): ${score.total}');
  sections.add('RSI condition triggered: ${evaluation.rsiTriggered}');

  final smc = evaluation.smc;
  sections.add('SMC current trend: ${smc.currentTrend?.name ?? 'undetermined'}');
  sections.add('SMC current zone: ${smc.currentZone.name}');
  if (smc.lastEvent != null) {
    sections.add(
      'Last market structure event: ${smc.lastEvent!.type.name.toUpperCase()} '
      '(${smc.lastEvent!.direction.name}) at index ${smc.lastEvent!.index}',
    );
  }
  sections.add('Unfilled Fair Value Gaps: ${smc.fairValueGaps.where((g) => !g.filled).length}');
  sections.add(
    'Active demand zones: ${smc.demandZones.length}, supply zones: ${smc.supplyZones.length}',
  );

  if (multiTimeframe != null && multiTimeframe.isNotEmpty) {
    final mtfLine = multiTimeframe.entries.map((e) => '${e.key}: ${e.value.name}').join(', ');
    sections.add('Multi-timeframe trend: $mtfLine');
  }

  return AiAnalysisContext(symbol: symbol, sections: sections);
}
