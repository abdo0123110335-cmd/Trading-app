/// Candle rendering style — the "Chart type" dropdown.
enum ChartStyle { candlestick, line, area, heikinAshi }

extension ChartStyleLabel on ChartStyle {
  String get label {
    switch (this) {
      case ChartStyle.candlestick:
        return 'Candlestick';
      case ChartStyle.line:
        return 'Line';
      case ChartStyle.area:
        return 'Area';
      case ChartStyle.heikinAshi:
        return 'Heikin Ashi';
    }
  }
}

/// Every timeframe the spec calls for, in Binance kline `interval` format,
/// in ascending order for the timeframe selector.
class ChartTimeframe {
  const ChartTimeframe(this.binanceInterval, this.label);
  final String binanceInterval;
  final String label;

  static const all = <ChartTimeframe>[
    ChartTimeframe('1m', '1m'),
    ChartTimeframe('3m', '3m'),
    ChartTimeframe('5m', '5m'),
    ChartTimeframe('15m', '15m'),
    ChartTimeframe('30m', '30m'),
    ChartTimeframe('1h', '1H'),
    ChartTimeframe('2h', '2H'),
    ChartTimeframe('4h', '4H'),
    ChartTimeframe('6h', '6H'),
    ChartTimeframe('12h', '12H'),
    ChartTimeframe('1d', '1D'),
    ChartTimeframe('1w', '1W'),
    ChartTimeframe('1M', '1M'),
  ];

  static const default_ = ChartTimeframe('1h', '1H');
}
