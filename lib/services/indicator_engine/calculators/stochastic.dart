import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';

class StochasticResult {
  const StochasticResult({required this.percentK, required this.percentD});
  final List<double?> percentK;
  final List<double?> percentD;
}

StochasticResult stochastic(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int kLength = 14,
  int kSmoothing = 3,
  int dLength = 3,
}) {
  final n = highs.length;
  final rawK = List<double?>.filled(n, null);

  for (var i = kLength - 1; i < n; i++) {
    double highest = highs[i - kLength + 1];
    double lowest = lows[i - kLength + 1];
    for (var j = i - kLength + 1; j <= i; j++) {
      if (highs[j] > highest) highest = highs[j];
      if (lows[j] < lowest) lowest = lows[j];
    }
    final range = highest - lowest;
    rawK[i] = range == 0 ? 0 : 100 * ((closes[i] - lowest) / range);
  }

  final firstValid = rawK.indexWhere((v) => v != null);
  final percentK = List<double?>.filled(n, null);
  if (firstValid != -1) {
    final rawValues = rawK.sublist(firstValid).cast<double>();
    final smoothed = sma(rawValues, kSmoothing);
    for (var i = 0; i < smoothed.length; i++) {
      percentK[firstValid + i] = smoothed[i];
    }
  }

  final firstK = percentK.indexWhere((v) => v != null);
  final percentD = List<double?>.filled(n, null);
  if (firstK != -1) {
    final kValues = percentK.sublist(firstK).cast<double>();
    final dSmoothed = sma(kValues, dLength);
    for (var i = 0; i < dSmoothed.length; i++) {
      percentD[firstK + i] = dSmoothed[i];
    }
  }

  return StochasticResult(percentK: percentK, percentD: percentD);
}
