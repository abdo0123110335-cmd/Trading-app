/// ROC = percentage change vs. `length` bars ago.
List<double?> roc(List<double> values, {int length = 12}) {
  final n = values.length;
  final out = List<double?>.filled(n, null);
  for (var i = length; i < n; i++) {
    final prev = values[i - length];
    out[i] = prev == 0 ? null : ((values[i] - prev) / prev) * 100;
  }
  return out;
}

/// Momentum = raw difference vs. `length` bars ago.
List<double?> momentum(List<double> values, {int length = 10}) {
  final n = values.length;
  final out = List<double?>.filled(n, null);
  for (var i = length; i < n; i++) {
    out[i] = values[i] - values[i - length];
  }
  return out;
}
