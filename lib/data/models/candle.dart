/// The one OHLCV representation used everywhere above the database layer
/// (chart, indicator engine, SMC engine, screener). [CandleRow] (Drift) is
/// mapped to/from this in the repository so the rest of the app never
/// touches generated Drift row types directly.
class Candle {
  const Candle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
    this.isClosed = true,
  });

  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime closeTime;
  final bool isClosed;

  /// Binance kline REST/WS array/object → [Candle]. Handles both the REST
  /// array-of-arrays kline format and the WS `k` kline payload object.
  factory Candle.fromRestArray(List<dynamic> a) {
    double parse(dynamic v) => double.tryParse('$v') ?? (v as num).toDouble();
    return Candle(
      openTime: DateTime.fromMillisecondsSinceEpoch(a[0] as int),
      open: parse(a[1]),
      high: parse(a[2]),
      low: parse(a[3]),
      close: parse(a[4]),
      volume: parse(a[5]),
      closeTime: DateTime.fromMillisecondsSinceEpoch(a[6] as int),
      isClosed: true,
    );
  }

  factory Candle.fromWsKline(Map<String, dynamic> k) {
    double parse(dynamic v) => double.tryParse('$v') ?? 0;
    return Candle(
      openTime: DateTime.fromMillisecondsSinceEpoch(k['t'] as int),
      open: parse(k['o']),
      high: parse(k['h']),
      low: parse(k['l']),
      close: parse(k['c']),
      volume: parse(k['v']),
      closeTime: DateTime.fromMillisecondsSinceEpoch(k['T'] as int),
      isClosed: k['x'] as bool? ?? false,
    );
  }

  Candle copyWith({
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
    bool? isClosed,
  }) {
    return Candle(
      openTime: openTime,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      closeTime: closeTime,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}

/// Which price to feed an indicator — mirrors TradingView's "Source"
/// dropdown (Close, Open, High, Low, HL2, HLC3, OHLC4).
enum PriceSource { open, high, low, close, hl2, hlc3, ohlc4 }

extension CandleSeriesX on List<Candle> {
  List<double> closes() => map((c) => c.close).toList();
  List<double> opens() => map((c) => c.open).toList();
  List<double> highs() => map((c) => c.high).toList();
  List<double> lows() => map((c) => c.low).toList();
  List<double> volumes() => map((c) => c.volume).toList();

  List<double> source(PriceSource s) {
    switch (s) {
      case PriceSource.open:
        return opens();
      case PriceSource.high:
        return highs();
      case PriceSource.low:
        return lows();
      case PriceSource.close:
        return closes();
      case PriceSource.hl2:
        return map((c) => (c.high + c.low) / 2).toList();
      case PriceSource.hlc3:
        return map((c) => (c.high + c.low + c.close) / 3).toList();
      case PriceSource.ohlc4:
        return map((c) => (c.open + c.high + c.low + c.close) / 4).toList();
    }
  }
}
