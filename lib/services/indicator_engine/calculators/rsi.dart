/// Relative Strength Index using Wilder's smoothing (the standard/original
/// method, matches TradingView's default RSI).
library;

List<double?> rsi(List<double> values, int length) {
  final out = List<double?>.filled(values.length, null);
  if (length <= 0 || values.length < length + 1) return out;

  double avgGain = 0;
  double avgLoss = 0;
  for (var i = 1; i <= length; i++) {
    final change = values[i] - values[i - 1];
    if (change >= 0) {
      avgGain += change;
    } else {
      avgLoss -= change;
    }
  }
  avgGain /= length;
  avgLoss /= length;
  out[length] = _rsiFromAverages(avgGain, avgLoss);

  for (var i = length + 1; i < values.length; i++) {
    final change = values[i] - values[i - 1];
    final gain = change > 0 ? change : 0.0;
    final loss = change < 0 ? -change : 0.0;
    avgGain = (avgGain * (length - 1) + gain) / length;
    avgLoss = (avgLoss * (length - 1) + loss) / length;
    out[i] = _rsiFromAverages(avgGain, avgLoss);
  }
  return out;
}

double _rsiFromAverages(double avgGain, double avgLoss) {
  if (avgLoss == 0) return 100;
  final rs = avgGain / avgLoss;
  return 100 - (100 / (1 + rs));
}

/// O(1)-per-tick Wilder RSI updater for the live pipeline.
class RsiIncremental {
  RsiIncremental({required this.length});

  final int length;
  double? _prevValue;
  double _avgGain = 0;
  double _avgLoss = 0;
  int _count = 0;
  double? _value;

  double? get value => _value;

  /// Feed historical closes once to warm up, in chronological order.
  void seedFromValues(List<double> warmupValues) {
    if (warmupValues.isEmpty) return;
    _prevValue = warmupValues.first;
    for (var i = 1; i < warmupValues.length; i++) {
      update(warmupValues[i]);
    }
  }

  double? update(double nextValue) {
    if (_prevValue == null) {
      _prevValue = nextValue;
      return null;
    }
    final change = nextValue - _prevValue!;
    _prevValue = nextValue;
    final gain = change > 0 ? change : 0.0;
    final loss = change < 0 ? -change : 0.0;
    _count++;

    if (_count <= length) {
      _avgGain += gain;
      _avgLoss += loss;
      if (_count == length) {
        _avgGain /= length;
        _avgLoss /= length;
        _value = _rsiFromAverages(_avgGain, _avgLoss);
      }
      return _value;
    }

    _avgGain = (_avgGain * (length - 1) + gain) / length;
    _avgLoss = (_avgLoss * (length - 1) + loss) / length;
    _value = _rsiFromAverages(_avgGain, _avgLoss);
    return _value;
  }
}
