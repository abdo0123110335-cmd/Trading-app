class Ticker24hr {
  const Ticker24hr({
    required this.symbol,
    required this.lastPrice,
    required this.priceChangePercent,
    required this.quoteVolume,
  });

  final String symbol;
  final double lastPrice;
  final double priceChangePercent;
  final double quoteVolume;

  factory Ticker24hr.fromJson(Map<String, dynamic> json) {
    double parse(dynamic v) => double.tryParse('$v') ?? 0;
    return Ticker24hr(
      symbol: json['symbol'] as String? ?? '',
      lastPrice: parse(json['lastPrice']),
      priceChangePercent: parse(json['priceChangePercent']),
      quoteVolume: parse(json['quoteVolume']),
    );
  }

  bool get isBullish => priceChangePercent >= 0;
}
