import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';

class MacdResult {
  const MacdResult({required this.macd, required this.signal, required this.histogram});
  final List<double?> macd;
  final List<double?> signal;
  final List<double?> histogram;
}

/// Standard MACD: EMA(fast) - EMA(slow), signal = EMA(macd, signalLength),
/// histogram = macd - signal. Defaults match the common 12/26/9 setup.
MacdResult macd(
  List<double> values, {
  int fastLength = 12,
  int slowLength = 26,
  int signalLength = 9,
}) {
  final fastEma = ema(values, fastLength);
  final slowEma = ema(values, slowLength);

  final macdLine = List<double?>.filled(values.length, null);
  for (var i = 0; i < values.length; i++) {
    final f = fastEma[i];
    final s = slowEma[i];
    if (f != null && s != null) macdLine[i] = f - s;
  }

  // EMA of the macd line, skipping the leading nulls.
  final firstValid = macdLine.indexWhere((v) => v != null);
  final signalLine = List<double?>.filled(values.length, null);
  if (firstValid != -1) {
    final macdValues = macdLine.sublist(firstValid).cast<double>();
    final signalEma = ema(macdValues, signalLength);
    for (var i = 0; i < signalEma.length; i++) {
      signalLine[firstValid + i] = signalEma[i];
    }
  }

  final histogram = List<double?>.filled(values.length, null);
  for (var i = 0; i < values.length; i++) {
    final m = macdLine[i];
    final s = signalLine[i];
    if (m != null && s != null) histogram[i] = m - s;
  }

  return MacdResult(macd: macdLine, signal: signalLine, histogram: histogram);
}
