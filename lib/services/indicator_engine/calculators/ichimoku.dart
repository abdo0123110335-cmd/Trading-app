class IchimokuResult {
  const IchimokuResult({
    required this.tenkanSen,
    required this.kijunSen,
    required this.senkouSpanA,
    required this.senkouSpanB,
    required this.chikouSpan,
  });

  final List<double?> tenkanSen;
  final List<double?> kijunSen;

  /// Plotted [displacement] bars ahead of the current bar (standard: 26).
  final List<double?> senkouSpanA;
  final List<double?> senkouSpanB;

  /// Plotted [displacement] bars behind the current bar.
  final List<double?> chikouSpan;
}

double? _midpoint(List<double> highs, List<double> lows, int end, int length) {
  final start = end - length + 1;
  if (start < 0) return null;
  double highest = highs[start];
  double lowest = lows[start];
  for (var j = start; j <= end; j++) {
    if (highs[j] > highest) highest = highs[j];
    if (lows[j] < lowest) lowest = lows[j];
  }
  return (highest + lowest) / 2;
}

IchimokuResult ichimoku(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int conversionLength = 9,
  int baseLength = 26,
  int leadingSpanBLength = 52,
  int displacement = 26,
}) {
  final n = highs.length;
  final tenkan = List<double?>.filled(n, null);
  final kijun = List<double?>.filled(n, null);
  final spanA = List<double?>.filled(n, null);
  final spanB = List<double?>.filled(n, null);
  final chikou = List<double?>.filled(n, null);

  for (var i = 0; i < n; i++) {
    tenkan[i] = _midpoint(highs, lows, i, conversionLength);
    kijun[i] = _midpoint(highs, lows, i, baseLength);
  }

  for (var i = 0; i < n; i++) {
    final t = tenkan[i];
    final k = kijun[i];
    final plotIndex = i + displacement;
    if (t != null && k != null && plotIndex < n) {
      spanA[plotIndex] = (t + k) / 2;
    }
    final b = _midpoint(highs, lows, i, leadingSpanBLength);
    if (b != null && plotIndex < n) {
      spanB[plotIndex] = b;
    }
    final chikouIndex = i - displacement;
    if (chikouIndex >= 0) {
      chikou[chikouIndex] = closes[i];
    }
  }

  return IchimokuResult(
    tenkanSen: tenkan,
    kijunSen: kijun,
    senkouSpanA: spanA,
    senkouSpanB: spanB,
    chikouSpan: chikou,
  );
}
