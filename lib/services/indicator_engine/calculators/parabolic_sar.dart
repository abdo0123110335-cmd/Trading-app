class ParabolicSarPoint {
  const ParabolicSarPoint({required this.value, required this.isUptrend});
  final double value;
  final bool isUptrend;
}

/// Parabolic SAR per Wilder's original method. Returns one point per bar
/// (null for the first bar, which has no prior trend to extend).
List<ParabolicSarPoint?> parabolicSar(
  List<double> highs,
  List<double> lows, {
  double step = 0.02,
  double maxStep = 0.2,
}) {
  final n = highs.length;
  final out = List<ParabolicSarPoint?>.filled(n, null);
  if (n < 2) return out;

  var isUptrend = highs[1] >= highs[0];
  var sar = isUptrend ? lows[0] : highs[0];
  var extremePoint = isUptrend ? highs[0] : lows[0];
  var accelFactor = step;

  for (var i = 1; i < n; i++) {
    sar = sar + accelFactor * (extremePoint - sar);

    if (isUptrend) {
      sar = sar > lows[i - 1] ? lows[i - 1] : sar;
      if (i >= 2) sar = sar > lows[i - 2] ? lows[i - 2] : sar;
    } else {
      sar = sar < highs[i - 1] ? highs[i - 1] : sar;
      if (i >= 2) sar = sar < highs[i - 2] ? highs[i - 2] : sar;
    }

    var reversed = false;
    if (isUptrend && lows[i] < sar) {
      isUptrend = false;
      reversed = true;
      sar = extremePoint;
      extremePoint = lows[i];
      accelFactor = step;
    } else if (!isUptrend && highs[i] > sar) {
      isUptrend = true;
      reversed = true;
      sar = extremePoint;
      extremePoint = highs[i];
      accelFactor = step;
    }

    if (!reversed) {
      if (isUptrend && highs[i] > extremePoint) {
        extremePoint = highs[i];
        accelFactor = (accelFactor + step).clamp(step, maxStep);
      } else if (!isUptrend && lows[i] < extremePoint) {
        extremePoint = lows[i];
        accelFactor = (accelFactor + step).clamp(step, maxStep);
      }
    }

    out[i] = ParabolicSarPoint(value: sar, isUptrend: isUptrend);
  }

  return out;
}
