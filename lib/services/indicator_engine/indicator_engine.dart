import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/adx.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/atr.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/bollinger_bands.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/cci.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/ichimoku.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/macd.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/parabolic_sar.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/roc_momentum.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/rsi.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/stochastic.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/volume_indicators.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/vwap.dart' as vwap_calc;
import 'package:binance_spot_pro/services/indicator_engine/calculators/williams_r.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_settings.dart';

/// Uniform output of any indicator computation: one or more named series,
/// index-aligned with the input candle list (nulls during warm-up).
/// Single-output indicators (RSI, EMA, ATR…) use the key `"value"`;
/// multi-output indicators use their natural component names
/// (`"macd"/"signal"/"histogram"`, `"upper"/"middle"/"lower"`, etc.).
class IndicatorResult {
  const IndicatorResult(this.series);
  final Map<String, List<double?>> series;

  List<double?> operator [](String key) => series[key] ?? const [];
  double? latest(String key) {
    final s = series[key];
    if (s == null || s.isEmpty) return null;
    return s.last;
  }
}

/// The single entry point every feature (Chart overlay, Screener,
/// Strategy Engine, SMC filters) uses to run an indicator over a candle
/// series. Pure/synchronous — safe to call directly for one symbol, or
/// via [runIndicatorBatchInIsolate] when scanning many symbols at once.
IndicatorResult computeIndicator(
  IndicatorType type,
  List<Candle> candles,
  IndicatorSettings settings,
) {
  if (candles.isEmpty) return const IndicatorResult({});

  final highs = candles.highs();
  final lows = candles.lows();
  final closes = candles.closes();
  final volumes = candles.volumes();
  final openTimes = candles.map((c) => c.openTime).toList();

  switch (type) {
    case IndicatorType.rsi:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      return IndicatorResult({'value': rsi(src, settings.getInt('length', 6))});

    case IndicatorType.ema:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      return IndicatorResult({'value': ema(src, settings.getInt('length', 21))});

    case IndicatorType.sma:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      return IndicatorResult({'value': sma(src, settings.getInt('length', 50))});

    case IndicatorType.wma:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      return IndicatorResult({'value': wma(src, settings.getInt('length', 21))});

    case IndicatorType.vwap:
      return IndicatorResult({
        'value': vwap_calc.vwap(highs, lows, closes, volumes, openTimes),
      });

    case IndicatorType.macd:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      final r = macd(
        src,
        fastLength: settings.getInt('fastLength', 12),
        slowLength: settings.getInt('slowLength', 26),
        signalLength: settings.getInt('signalLength', 9),
      );
      return IndicatorResult({'macd': r.macd, 'signal': r.signal, 'histogram': r.histogram});

    case IndicatorType.bollingerBands:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      final r = bollingerBands(
        src,
        length: settings.getInt('length', 20),
        stdDevMultiplier: settings.getDouble('stdDev', 2),
      );
      return IndicatorResult({'upper': r.upper, 'middle': r.middle, 'lower': r.lower});

    case IndicatorType.atr:
      return IndicatorResult({
        'value': atrFromOhlc(highs, lows, closes, length: settings.getInt('length', 14)),
      });

    case IndicatorType.adx:
      final r = adx(highs, lows, closes, length: settings.getInt('length', 14));
      return IndicatorResult({'adx': r.adx, 'plusDi': r.plusDi, 'minusDi': r.minusDi});

    case IndicatorType.cci:
      return IndicatorResult({
        'value': cci(highs, lows, closes, length: settings.getInt('length', 20)),
      });

    case IndicatorType.stochastic:
      final r = stochastic(
        highs,
        lows,
        closes,
        kLength: settings.getInt('kLength', 14),
        kSmoothing: settings.getInt('kSmoothing', 3),
        dLength: settings.getInt('dLength', 3),
      );
      return IndicatorResult({'k': r.percentK, 'd': r.percentD});

    case IndicatorType.williamsR:
      return IndicatorResult({
        'value': williamsR(highs, lows, closes, length: settings.getInt('length', 14)),
      });

    case IndicatorType.obv:
      return IndicatorResult({'value': obv(closes, volumes)});

    case IndicatorType.mfi:
      return IndicatorResult({
        'value': mfi(highs, lows, closes, volumes, length: settings.getInt('length', 14)),
      });

    case IndicatorType.roc:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      return IndicatorResult({'value': roc(src, length: settings.getInt('length', 12))});

    case IndicatorType.momentum:
      final src = candles.source(settings.getSource('source', PriceSource.close));
      return IndicatorResult({'value': momentum(src, length: settings.getInt('length', 10))});

    case IndicatorType.ichimoku:
      final r = ichimoku(
        highs,
        lows,
        closes,
        conversionLength: settings.getInt('conversionLength', 9),
        baseLength: settings.getInt('baseLength', 26),
        leadingSpanBLength: settings.getInt('leadingSpanBLength', 52),
        displacement: settings.getInt('displacement', 26),
      );
      return IndicatorResult({
        'tenkanSen': r.tenkanSen,
        'kijunSen': r.kijunSen,
        'senkouSpanA': r.senkouSpanA,
        'senkouSpanB': r.senkouSpanB,
        'chikouSpan': r.chikouSpan,
      });

    case IndicatorType.parabolicSar:
      final points = parabolicSar(
        highs,
        lows,
        step: settings.getDouble('step', 0.02),
        maxStep: settings.getDouble('maxStep', 0.2),
      );
      return IndicatorResult({
        'value': points.map((p) => p?.value).toList(),
        // +1 uptrend / -1 downtrend, encoded numerically to stay inside
        // the uniform double-series result shape.
        'trend': points.map((p) => p == null ? null : (p.isUptrend ? 1.0 : -1.0)).toList(),
      });
  }
}
