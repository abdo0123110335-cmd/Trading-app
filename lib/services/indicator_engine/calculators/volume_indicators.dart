/// OBV: running total, +volume on up closes, -volume on down closes.
List<double> obv(List<double> closes, List<double> volumes) {
  final n = closes.length;
  final out = List<double>.filled(n, 0);
  if (n == 0) return out;
  out[0] = 0;
  for (var i = 1; i < n; i++) {
    if (closes[i] > closes[i - 1]) {
      out[i] = out[i - 1] + volumes[i];
    } else if (closes[i] < closes[i - 1]) {
      out[i] = out[i - 1] - volumes[i];
    } else {
      out[i] = out[i - 1];
    }
  }
  return out;
}

/// Money Flow Index — RSI's volume-weighted cousin.
List<double?> mfi(
  List<double> highs,
  List<double> lows,
  List<double> closes,
  List<double> volumes, {
  int length = 14,
}) {
  final n = highs.length;
  final typical = List<double>.generate(n, (i) => (highs[i] + lows[i] + closes[i]) / 3);
  final rawMoneyFlow = List<double>.generate(n, (i) => typical[i] * volumes[i]);
  final out = List<double?>.filled(n, null);

  for (var i = length; i < n; i++) {
    double positiveFlow = 0;
    double negativeFlow = 0;
    for (var j = i - length + 1; j <= i; j++) {
      if (typical[j] > typical[j - 1]) {
        positiveFlow += rawMoneyFlow[j];
      } else if (typical[j] < typical[j - 1]) {
        negativeFlow += rawMoneyFlow[j];
      }
    }
    if (negativeFlow == 0) {
      out[i] = 100;
    } else {
      final moneyRatio = positiveFlow / negativeFlow;
      out[i] = 100 - (100 / (1 + moneyRatio));
    }
  }
  return out;
}
