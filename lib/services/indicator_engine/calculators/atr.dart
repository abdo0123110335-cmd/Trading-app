import 'dart:math' as math;

/// True Range per bar, then Wilder-smoothed average (ATR). Standalone from
/// [Candle] so it can be reused by ADX without a circular import.
List<double?> atrFromOhlc(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int length = 14,
}) {
  final n = highs.length;
  final tr = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    if (i == 0) {
      tr[i] = highs[i] - lows[i];
      continue;
    }
    final hl = highs[i] - lows[i];
    final hc = (highs[i] - closes[i - 1]).abs();
    final lc = (lows[i] - closes[i - 1]).abs();
    tr[i] = math.max(hl, math.max(hc, lc));
  }

  final out = List<double?>.filled(n, null);
  if (n < length) return out;

  double avg = 0;
  for (var i = 0; i < length; i++) {
    avg += tr[i];
  }
  avg /= length;
  out[length - 1] = avg;

  for (var i = length; i < n; i++) {
    avg = (avg * (length - 1) + tr[i]) / length;
    out[i] = avg;
  }
  return out;
}
