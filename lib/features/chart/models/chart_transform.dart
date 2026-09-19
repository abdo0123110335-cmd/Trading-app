import 'package:binance_spot_pro/data/models/candle.dart';

/// Pure coordinate math for the chart viewport. Rebuilt every frame from
/// the controller's pan/zoom state — deliberately stateless so painters,
/// gesture handlers and the drawing layer can never disagree about where
/// a given candle/price sits on screen.
class ChartTransform {
  ChartTransform({
    required this.candles,
    required this.firstVisibleIndex,
    required this.visibleCount,
    required this.width,
    required this.priceAreaHeight,
    double? manualPriceMin,
    double? manualPriceMax,
  }) {
    if (manualPriceMin != null && manualPriceMax != null) {
      priceMin = manualPriceMin;
      priceMax = manualPriceMax;
    } else {
      final range = _visiblePriceRange();
      final padding = (range.$2 - range.$1) * 0.08;
      priceMin = range.$1 - padding;
      priceMax = range.$2 + padding;
      if (priceMax <= priceMin) {
        priceMax = priceMin + 1;
      }
    }
  }

  final List<Candle> candles;
  final double firstVisibleIndex;
  final double visibleCount;
  final double width;
  final double priceAreaHeight;

  late final double priceMin;
  late final double priceMax;

  double get candleWidth => width / visibleCount;

  int get firstIndexClamped =>
      firstVisibleIndex.floor().clamp(0, candles.isEmpty ? 0 : candles.length - 1);
  int get lastIndexClamped =>
      (firstVisibleIndex + visibleCount).ceil().clamp(0, candles.isEmpty ? 0 : candles.length - 1);

  (double, double) _visiblePriceRange() {
    if (candles.isEmpty) return (0, 1);
    final start = firstIndexClamped;
    final end = lastIndexClamped;
    double lo = candles[start].low;
    double hi = candles[start].high;
    for (var i = start; i <= end && i < candles.length; i++) {
      if (candles[i].low < lo) lo = candles[i].low;
      if (candles[i].high > hi) hi = candles[i].high;
    }
    return (lo, hi);
  }

  double xForIndex(double index) => (index - firstVisibleIndex) * candleWidth;
  double indexForX(double x) => firstVisibleIndex + x / candleWidth;

  double yForPrice(double price) {
    final t = (price - priceMin) / (priceMax - priceMin);
    return priceAreaHeight * (1 - t);
  }

  double priceForY(double y) {
    final t = 1 - (y / priceAreaHeight);
    return priceMin + t * (priceMax - priceMin);
  }
}
