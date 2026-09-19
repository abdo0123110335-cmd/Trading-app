import 'dart:math' as math;

import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';

class BollingerBandsResult {
  const BollingerBandsResult({required this.upper, required this.middle, required this.lower});
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;
}

BollingerBandsResult bollingerBands(
  List<double> values, {
  int length = 20,
  double stdDevMultiplier = 2,
}) {
  final middle = sma(values, length);
  final upper = List<double?>.filled(values.length, null);
  final lower = List<double?>.filled(values.length, null);

  for (var i = length - 1; i < values.length; i++) {
    final m = middle[i];
    if (m == null) continue;
    double sumSq = 0;
    for (var j = i - length + 1; j <= i; j++) {
      sumSq += math.pow(values[j] - m, 2);
    }
    final stdDev = math.sqrt(sumSq / length);
    upper[i] = m + stdDevMultiplier * stdDev;
    lower[i] = m - stdDevMultiplier * stdDev;
  }

  return BollingerBandsResult(upper: upper, middle: middle, lower: lower);
}
