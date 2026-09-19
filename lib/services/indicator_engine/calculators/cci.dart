/// CCI = (typicalPrice - SMA(typicalPrice)) / (0.015 * mean absolute deviation)
List<double?> cci(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int length = 20,
}) {
  final n = highs.length;
  final typical = List<double>.generate(n, (i) => (highs[i] + lows[i] + closes[i]) / 3);
  final out = List<double?>.filled(n, null);

  for (var i = length - 1; i < n; i++) {
    double sum = 0;
    for (var j = i - length + 1; j <= i; j++) {
      sum += typical[j];
    }
    final smaTp = sum / length;

    double meanDeviation = 0;
    for (var j = i - length + 1; j <= i; j++) {
      meanDeviation += (typical[j] - smaTp).abs();
    }
    meanDeviation /= length;

    out[i] = meanDeviation == 0 ? 0 : (typical[i] - smaTp) / (0.015 * meanDeviation);
  }
  return out;
}
