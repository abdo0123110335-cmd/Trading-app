import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

/// One line item in the score breakdown, shown to the user so the score
/// is explainable rather than a black box (e.g. Settings/Signal detail:
/// "RSI 18/20", "EMA 0/15", ...).
class ScoreComponent {
  const ScoreComponent({required this.label, required this.earned, required this.max});
  final String label;
  final double earned;
  final double max;
}

class ScoreResult {
  const ScoreResult({required this.total, required this.components});
  final int total; // 0-100, rounded
  final List<ScoreComponent> components;
}

/// Computes the 0-100 Score System from a [StrategyEvaluation] using the
/// weights in [config]. Score is NOT a guarantee of profit — it measures
/// how many of the strategy's bullish conditions currently line up, per
/// the spec's explicit "Score is not a guarantee of profit" requirement.
ScoreResult computeScore(StrategyEvaluation evaluation, StrategyConfig config) {
  final totalWeight = config.weightRsi +
      config.weightEma +
      config.weightMacd +
      config.weightVolume +
      config.weightTrend +
      config.weightSmc +
      config.weightSupport;
  final normalizer = totalWeight == 0 ? 1 : 100 / totalWeight;

  // RSI: full credit at/below oversold, scaling down to zero as RSI rises
  // back toward the oversold threshold from below (deeper oversold = more
  // credit, matching how traders actually read RSI extremity).
  double rsiEarned = 0;
  final rsi = evaluation.rsiValue;
  if (rsi != null && evaluation.rsiTriggered) {
    final depth = (config.rsiOversold - rsi).clamp(0, config.rsiOversold);
    final depthRatio = config.rsiOversold == 0 ? 1.0 : (depth / config.rsiOversold).clamp(0.4, 1.0);
    rsiEarned = config.weightRsi * depthRatio;
  }

  double flagEarned(FilterCheck check, double weight) => check.passed ? weight : 0;

  final components = <ScoreComponent>[
    ScoreComponent(label: 'RSI', earned: rsiEarned * normalizer, max: config.weightRsi * normalizer),
    ScoreComponent(
      label: 'EMA',
      earned: flagEarned(evaluation.emaFilter, config.weightEma) * normalizer,
      max: config.weightEma * normalizer,
    ),
    ScoreComponent(
      label: 'MACD',
      earned: flagEarned(evaluation.macdFilter, config.weightMacd) * normalizer,
      max: config.weightMacd * normalizer,
    ),
    ScoreComponent(
      label: 'Volume',
      earned: flagEarned(evaluation.volumeFilter, config.weightVolume) * normalizer,
      max: config.weightVolume * normalizer,
    ),
    ScoreComponent(
      label: 'Trend',
      earned: flagEarned(evaluation.trendFilter, config.weightTrend) * normalizer,
      max: config.weightTrend * normalizer,
    ),
    ScoreComponent(
      label: 'SMC',
      earned: flagEarned(evaluation.smcFilter, config.weightSmc) * normalizer,
      max: config.weightSmc * normalizer,
    ),
    ScoreComponent(
      label: 'Support',
      earned: flagEarned(evaluation.supportFilter, config.weightSupport) * normalizer,
      max: config.weightSupport * normalizer,
    ),
  ];

  final total = components.fold<double>(0, (sum, c) => sum + c.earned);
  return ScoreResult(total: total.round().clamp(0, 100), components: components);
}
