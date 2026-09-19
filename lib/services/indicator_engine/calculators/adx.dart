class AdxResult {
  const AdxResult({required this.adx, required this.plusDi, required this.minusDi});
  final List<double?> adx;
  final List<double?> plusDi;
  final List<double?> minusDi;
}

AdxResult adx(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int length = 14,
}) {
  final n = highs.length;
  final plusDm = List<double>.filled(n, 0);
  final minusDm = List<double>.filled(n, 0);
  final tr = List<double>.filled(n, 0);

  for (var i = 1; i < n; i++) {
    final upMove = highs[i] - highs[i - 1];
    final downMove = lows[i - 1] - lows[i];
    plusDm[i] = (upMove > downMove && upMove > 0) ? upMove : 0;
    minusDm[i] = (downMove > upMove && downMove > 0) ? downMove : 0;

    final hl = highs[i] - lows[i];
    final hc = (highs[i] - closes[i - 1]).abs();
    final lc = (lows[i] - closes[i - 1]).abs();
    tr[i] = [hl, hc, lc].reduce((a, b) => a > b ? a : b);
  }

  final plusDi = List<double?>.filled(n, null);
  final minusDi = List<double?>.filled(n, null);
  final adxOut = List<double?>.filled(n, null);
  if (n < length * 2) {
    return AdxResult(adx: adxOut, plusDi: plusDi, minusDi: minusDi);
  }

  double smoothedTr = 0, smoothedPlusDm = 0, smoothedMinusDm = 0;
  for (var i = 1; i <= length; i++) {
    smoothedTr += tr[i];
    smoothedPlusDm += plusDm[i];
    smoothedMinusDm += minusDm[i];
  }

  final dx = List<double?>.filled(n, null);

  void computeDiAndDx(int i) {
    final pDi = smoothedTr == 0 ? 0 : 100 * (smoothedPlusDm / smoothedTr);
    final mDi = smoothedTr == 0 ? 0 : 100 * (smoothedMinusDm / smoothedTr);
    plusDi[i] = pDi.toDouble();
    minusDi[i] = mDi.toDouble();
    final sum = pDi + mDi;
    dx[i] = sum == 0 ? 0 : 100 * ((pDi - mDi).abs() / sum);
  }

  computeDiAndDx(length);

  for (var i = length + 1; i < n; i++) {
    smoothedTr = smoothedTr - (smoothedTr / length) + tr[i];
    smoothedPlusDm = smoothedPlusDm - (smoothedPlusDm / length) + plusDm[i];
    smoothedMinusDm = smoothedMinusDm - (smoothedMinusDm / length) + minusDm[i];
    computeDiAndDx(i);
  }

  // ADX = Wilder-smoothed average of DX, starting after 2*length bars.
  final firstDx = length;
  final adxSeedEnd = firstDx + length;
  if (adxSeedEnd >= n) {
    return AdxResult(adx: adxOut, plusDi: plusDi, minusDi: minusDi);
  }

  double sumDx = 0;
  for (var i = firstDx; i < adxSeedEnd; i++) {
    sumDx += dx[i] ?? 0;
  }
  double avgDx = sumDx / length;
  adxOut[adxSeedEnd - 1] = avgDx;

  for (var i = adxSeedEnd; i < n; i++) {
    avgDx = (avgDx * (length - 1) + (dx[i] ?? 0)) / length;
    adxOut[i] = avgDx;
  }

  return AdxResult(adx: adxOut, plusDi: plusDi, minusDi: minusDi);
}
