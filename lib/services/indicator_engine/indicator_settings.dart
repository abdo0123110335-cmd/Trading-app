import 'package:binance_spot_pro/data/models/candle.dart';

enum IndicatorType {
  rsi,
  ema,
  sma,
  wma,
  vwap,
  macd,
  bollingerBands,
  atr,
  adx,
  cci,
  stochastic,
  williamsR,
  obv,
  mfi,
  roc,
  momentum,
  ichimoku,
  parabolicSar,
}

extension IndicatorTypeLabel on IndicatorType {
  String get label {
    switch (this) {
      case IndicatorType.rsi:
        return 'RSI';
      case IndicatorType.ema:
        return 'EMA';
      case IndicatorType.sma:
        return 'SMA';
      case IndicatorType.wma:
        return 'WMA';
      case IndicatorType.vwap:
        return 'VWAP';
      case IndicatorType.macd:
        return 'MACD';
      case IndicatorType.bollingerBands:
        return 'Bollinger Bands';
      case IndicatorType.atr:
        return 'ATR';
      case IndicatorType.adx:
        return 'ADX';
      case IndicatorType.cci:
        return 'CCI';
      case IndicatorType.stochastic:
        return 'Stochastic';
      case IndicatorType.williamsR:
        return 'Williams %R';
      case IndicatorType.obv:
        return 'OBV';
      case IndicatorType.mfi:
        return 'MFI';
      case IndicatorType.roc:
        return 'ROC';
      case IndicatorType.momentum:
        return 'Momentum';
      case IndicatorType.ichimoku:
        return 'Ichimoku';
      case IndicatorType.parabolicSar:
        return 'Parabolic SAR';
    }
  }
}

/// A flexible settings bag for one indicator instance. Values are stored
/// loosely typed (matches how they're persisted as JSON in the
/// `indicators` table's `settingsJson` column) with typed accessors here
/// so calculators don't sprinkle `as double` casts everywhere.
class IndicatorSettings {
  IndicatorSettings(Map<String, dynamic> values) : _values = Map.of(values);

  final Map<String, dynamic> _values;

  int getInt(String key, int fallback) => (_values[key] as num?)?.toInt() ?? fallback;
  double getDouble(String key, double fallback) => (_values[key] as num?)?.toDouble() ?? fallback;
  PriceSource getSource(String key, PriceSource fallback) {
    final raw = _values[key] as String?;
    if (raw == null) return fallback;
    return PriceSource.values.firstWhere((s) => s.name == raw, orElse: () => fallback);
  }

  Map<String, dynamic> toJson() => Map.of(_values);

  /// Sensible, spec-aligned defaults per indicator. RSI defaults match the
  /// project's default strategy (length 6) rather than the generic 14, so
  /// a freshly-added RSI on the chart matches what the Strategy Engine
  /// uses out of the box.
  factory IndicatorSettings.defaultsFor(IndicatorType type) {
    switch (type) {
      case IndicatorType.rsi:
        return IndicatorSettings({
          'length': 6,
          'source': PriceSource.close.name,
          'overbought': 70,
          'oversold': 30,
        });
      case IndicatorType.ema:
        return IndicatorSettings({'length': 21, 'source': PriceSource.close.name});
      case IndicatorType.sma:
        return IndicatorSettings({'length': 50, 'source': PriceSource.close.name});
      case IndicatorType.wma:
        return IndicatorSettings({'length': 21, 'source': PriceSource.close.name});
      case IndicatorType.vwap:
        return IndicatorSettings({});
      case IndicatorType.macd:
        return IndicatorSettings({
          'fastLength': 12,
          'slowLength': 26,
          'signalLength': 9,
          'source': PriceSource.close.name,
        });
      case IndicatorType.bollingerBands:
        return IndicatorSettings({
          'length': 20,
          'stdDev': 2,
          'source': PriceSource.close.name,
        });
      case IndicatorType.atr:
        return IndicatorSettings({'length': 14});
      case IndicatorType.adx:
        return IndicatorSettings({'length': 14});
      case IndicatorType.cci:
        return IndicatorSettings({'length': 20});
      case IndicatorType.stochastic:
        return IndicatorSettings({'kLength': 14, 'kSmoothing': 3, 'dLength': 3});
      case IndicatorType.williamsR:
        return IndicatorSettings({'length': 14});
      case IndicatorType.obv:
        return IndicatorSettings({});
      case IndicatorType.mfi:
        return IndicatorSettings({'length': 14});
      case IndicatorType.roc:
        return IndicatorSettings({'length': 12, 'source': PriceSource.close.name});
      case IndicatorType.momentum:
        return IndicatorSettings({'length': 10, 'source': PriceSource.close.name});
      case IndicatorType.ichimoku:
        return IndicatorSettings({
          'conversionLength': 9,
          'baseLength': 26,
          'leadingSpanBLength': 52,
          'displacement': 26,
        });
      case IndicatorType.parabolicSar:
        return IndicatorSettings({'step': 0.02, 'maxStep': 0.2});
    }
  }
}
