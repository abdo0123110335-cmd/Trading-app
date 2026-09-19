/// Moving average calculators.
///
/// Two APIs are provided on purpose:
///   * Batch (`sma`/`ema`/`wma`) — recomputes the full output series from a
///     full price array. Used when a chart/screener first loads history.
///   * Incremental (`EmaIncremental`/`SmaIncremental`) — O(1) update per new
///     tick/candle close, used by the live pipeline so a WebSocket tick
///     never triggers an O(n) recalculation over the whole visible
///     history. This is the "Incremental Calculations" requirement from
///     the spec, applied where it actually matters (EMA/SMA feed almost
///     every other indicator: MACD, Bollinger basis, trend filters).
library;

/// Simple Moving Average. First `length - 1` values are `null` (warm-up).
List<double?> sma(List<double> values, int length) {
  final out = List<double?>.filled(values.length, null);
  if (length <= 0 || values.length < length) return out;
  double sum = 0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= length) sum -= values[i - length];
    if (i >= length - 1) out[i] = sum / length;
  }
  return out;
}

/// Exponential Moving Average, seeded with an SMA of the first `length`
/// values (standard convention).
List<double?> ema(List<double> values, int length) {
  final out = List<double?>.filled(values.length, null);
  if (length <= 0 || values.length < length) return out;
  final k = 2 / (length + 1);

  double seed = 0;
  for (var i = 0; i < length; i++) {
    seed += values[i];
  }
  seed /= length;
  out[length - 1] = seed;

  var prev = seed;
  for (var i = length; i < values.length; i++) {
    final next = (values[i] - prev) * k + prev;
    out[i] = next;
    prev = next;
  }
  return out;
}

/// Weighted Moving Average — most recent value weighted most heavily.
List<double?> wma(List<double> values, int length) {
  final out = List<double?>.filled(values.length, null);
  if (length <= 0 || values.length < length) return out;
  final denom = length * (length + 1) / 2;
  for (var i = length - 1; i < values.length; i++) {
    double weightedSum = 0;
    for (var j = 0; j < length; j++) {
      weightedSum += values[i - j] * (length - j);
    }
    out[i] = weightedSum / denom;
  }
  return out;
}

/// O(1)-per-tick EMA updater for the live pipeline. Construct once from a
/// warmed-up batch `ema(...)` call (or [seedFromValues]), then call
/// [update] on every new closed candle instead of recomputing the array.
class EmaIncremental {
  EmaIncremental({required this.length, double? seed})
    : _k = 2 / (length + 1),
      _value = seed;

  final int length;
  final double _k;
  double? _value;

  double? get value => _value;

  /// Seeds the EMA from a plain SMA of the first [length] values of a
  /// historical series — call once before streaming live updates.
  void seedFromValues(List<double> warmupValues) {
    if (warmupValues.length < length) return;
    double sum = 0;
    for (var i = 0; i < length; i++) {
      sum += warmupValues[i];
    }
    _value = sum / length;
    for (var i = length; i < warmupValues.length; i++) {
      _value = (warmupValues[i] - _value!) * _k + _value!;
    }
  }

  /// Feed the next closed-candle price; returns the updated EMA value.
  double update(double nextValue) {
    if (_value == null) {
      _value = nextValue;
      return _value!;
    }
    _value = (nextValue - _value!) * _k + _value!;
    return _value!;
  }
}

/// O(1)-per-tick simple moving average using a ring buffer, avoiding an
/// O(length) resum on every new candle.
class SmaIncremental {
  SmaIncremental({required this.length});

  final int length;
  final List<double> _window = [];
  double _sum = 0;

  double? get value => _window.length < length ? null : _sum / length;

  double? update(double nextValue) {
    _window.add(nextValue);
    _sum += nextValue;
    if (_window.length > length) {
      _sum -= _window.removeAt(0);
    }
    return value;
  }
}
