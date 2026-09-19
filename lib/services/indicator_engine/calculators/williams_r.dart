List<double?> williamsR(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int length = 14,
}) {
  final n = highs.length;
  final out = List<double?>.filled(n, null);
  for (var i = length - 1; i < n; i++) {
    double highest = highs[i - length + 1];
    double lowest = lows[i - length + 1];
    for (var j = i - length + 1; j <= i; j++) {
      if (highs[j] > highest) highest = highs[j];
      if (lows[j] < lowest) lowest = lows[j];
    }
    final range = highest - lowest;
    out[i] = range == 0 ? 0 : -100 * ((highest - closes[i]) / range);
  }
  return out;
}
