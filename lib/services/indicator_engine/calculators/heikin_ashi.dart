import 'package:binance_spot_pro/data/models/candle.dart';

/// Converts a regular OHLC series into Heikin Ashi candles.
/// HA-Close = (O+H+L+C)/4; HA-Open = avg(prevHAOpen, prevHAClose) (first
/// bar seeds from its own O/C); HA-High/Low = max/min of the bar's H/L and
/// the new HA-Open/Close, per the standard formula.
List<Candle> toHeikinAshi(List<Candle> source) {
  if (source.isEmpty) return const [];
  final out = <Candle>[];
  double prevHaOpen = source.first.open;
  double prevHaClose = source.first.close;

  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    final haClose = (c.open + c.high + c.low + c.close) / 4;
    final haOpen = i == 0 ? (c.open + c.close) / 2 : (prevHaOpen + prevHaClose) / 2;
    final haHigh = [c.high, haOpen, haClose].reduce((a, b) => a > b ? a : b);
    final haLow = [c.low, haOpen, haClose].reduce((a, b) => a < b ? a : b);

    out.add(
      Candle(
        openTime: c.openTime,
        open: haOpen,
        high: haHigh,
        low: haLow,
        close: haClose,
        volume: c.volume,
        closeTime: c.closeTime,
        isClosed: c.isClosed,
      ),
    );

    prevHaOpen = haOpen;
    prevHaClose = haClose;
  }
  return out;
}
