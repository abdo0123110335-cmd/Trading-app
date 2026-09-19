import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/features/chart/models/chart_transform.dart';
import 'package:binance_spot_pro/features/chart/models/chart_types.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_engine.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_settings.dart';

class ChartPainter extends CustomPainter {
  ChartPainter({
    required this.candles,
    required this.chartStyle,
    required this.firstVisibleIndex,
    required this.visibleCount,
    required this.overlays,
    this.crosshairPixel,
  });

  final List<Candle> candles;
  final ChartStyle chartStyle;
  final double firstVisibleIndex;
  final double visibleCount;
  final Map<IndicatorType, IndicatorResult> overlays;
  final Offset? crosshairPixel;

  static const double _volumeAreaFraction = 0.18;
  static const double _priceAxisWidth = 64;
  static const double _timeAxisHeight = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final priceAreaHeight =
        size.height - _timeAxisHeight - (size.height * _volumeAreaFraction);
    final chartWidth = size.width - _priceAxisWidth;

    final transform = ChartTransform(
      candles: candles,
      firstVisibleIndex: firstVisibleIndex,
      visibleCount: visibleCount,
      width: chartWidth,
      priceAreaHeight: priceAreaHeight,
    );

    _drawGrid(canvas, transform, priceAreaHeight, chartWidth);
    if (candles.isNotEmpty) {
      switch (chartStyle) {
        case ChartStyle.candlestick:
        case ChartStyle.heikinAshi:
          _drawCandles(canvas, transform);
        case ChartStyle.line:
          _drawLine(canvas, transform, filled: false, areaHeight: priceAreaHeight);
        case ChartStyle.area:
          _drawLine(canvas, transform, filled: true, areaHeight: priceAreaHeight);
      }
      _drawVolume(canvas, transform, priceAreaHeight, size.height - _timeAxisHeight);
      _drawOverlays(canvas, transform);
      _drawPriceAxis(canvas, transform, priceAreaHeight, chartWidth);
      _drawTimeAxis(canvas, size, transform, chartWidth);
    }
    if (crosshairPixel != null) {
      _drawCrosshair(canvas, transform, chartWidth, priceAreaHeight);
    }
  }

  void _drawGrid(Canvas canvas, ChartTransform t, double priceAreaHeight, double chartWidth) {
    final paint = Paint()
      ..color = MarketColors.borderDark
      ..strokeWidth = 0.5;
    const hLines = 4;
    for (var i = 0; i <= hLines; i++) {
      final y = priceAreaHeight * i / hLines;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), paint);
    }
  }

  void _drawCandles(Canvas canvas, ChartTransform t) {
    final bullPaint = Paint()..color = MarketColors.bullish;
    final bearPaint = Paint()..color = MarketColors.bearish;
    const bodyWidthFactor = 0.7;

    for (var i = t.firstIndexClamped; i <= t.lastIndexClamped && i < candles.length; i++) {
      final c = candles[i];
      final x = t.xForIndex(i.toDouble()) + t.candleWidth / 2;
      final isBull = c.close >= c.open;
      final paint = isBull ? bullPaint : bearPaint;

      final highY = t.yForPrice(c.high);
      final lowY = t.yForPrice(c.low);
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), Paint()..color = paint.color..strokeWidth = 1);

      final openY = t.yForPrice(c.open);
      final closeY = t.yForPrice(c.close);
      final bodyTop = openY < closeY ? openY : closeY;
      final bodyBottom = openY < closeY ? closeY : openY;
      final bodyWidth = t.candleWidth * bodyWidthFactor;
      final rect = Rect.fromLTRB(
        x - bodyWidth / 2,
        bodyTop,
        x + bodyWidth / 2,
        bodyBottom < bodyTop + 1 ? bodyTop + 1 : bodyBottom,
      );
      canvas.drawRect(rect, paint);
    }
  }

  void _drawLine(Canvas canvas, ChartTransform t, {required bool filled, required double areaHeight}) {
    final path = Path();
    var started = false;
    for (var i = t.firstIndexClamped; i <= t.lastIndexClamped && i < candles.length; i++) {
      final x = t.xForIndex(i.toDouble()) + t.candleWidth / 2;
      final y = t.yForPrice(candles[i].close);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (filled && started) {
      final fillPath = Path.from(path)
        ..lineTo(t.xForIndex(t.lastIndexClamped.toDouble()) + t.candleWidth / 2, areaHeight)
        ..lineTo(t.xForIndex(t.firstIndexClamped.toDouble()) + t.candleWidth / 2, areaHeight)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MarketColors.bullish.withValues(alpha: 0.25), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, 0, t.width, areaHeight)),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = MarketColors.bullish
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  void _drawVolume(Canvas canvas, ChartTransform t, double priceAreaHeight, double bottomY) {
    final volumeTop = priceAreaHeight + 8;
    final volumeHeight = bottomY - volumeTop;
    if (volumeHeight <= 0) return;

    final start = t.firstIndexClamped;
    final end = t.lastIndexClamped;
    double maxVol = 0;
    for (var i = start; i <= end && i < candles.length; i++) {
      if (candles[i].volume > maxVol) maxVol = candles[i].volume;
    }
    if (maxVol == 0) return;

    for (var i = start; i <= end && i < candles.length; i++) {
      final c = candles[i];
      final x = t.xForIndex(i.toDouble()) + t.candleWidth / 2;
      final h = (c.volume / maxVol) * volumeHeight;
      final isBull = c.close >= c.open;
      final paint = Paint()
        ..color = (isBull ? MarketColors.bullish : MarketColors.bearish).withValues(alpha: 0.5);
      final barWidth = t.candleWidth * 0.7;
      canvas.drawRect(
        Rect.fromLTRB(x - barWidth / 2, bottomY - h, x + barWidth / 2, bottomY),
        paint,
      );
    }
  }

  void _drawOverlays(Canvas canvas, ChartTransform t) {
    for (final entry in overlays.entries) {
      final series = entry.value['value'];
      if (series.isEmpty) continue;
      final path = Path();
      var started = false;
      for (var i = t.firstIndexClamped; i <= t.lastIndexClamped && i < series.length; i++) {
        final v = series[i];
        if (v == null) continue;
        final x = t.xForIndex(i.toDouble()) + t.candleWidth / 2;
        final y = t.yForPrice(v);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = MarketColors.warning
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _drawPriceAxis(Canvas canvas, ChartTransform t, double priceAreaHeight, double chartWidth) {
    const steps = 4;
    for (var i = 0; i <= steps; i++) {
      final y = priceAreaHeight * i / steps;
      final price = t.priceForY(y);
      final tp = TextPainter(
        text: TextSpan(
          text: _formatPrice(price),
          style: const TextStyle(color: MarketColors.neutral, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartWidth + 6, y - tp.height / 2));
    }
  }

  void _drawTimeAxis(Canvas canvas, Size size, ChartTransform t, double chartWidth) {
    final fmt = DateFormat('HH:mm');
    const labelCount = 4;
    for (var i = 0; i <= labelCount; i++) {
      final index = (t.firstIndexClamped +
              (t.lastIndexClamped - t.firstIndexClamped) * i / labelCount)
          .round()
          .clamp(0, candles.length - 1);
      final x = t.xForIndex(index.toDouble());
      final tp = TextPainter(
        text: TextSpan(
          text: fmt.format(candles[index].openTime.toLocal()),
          style: const TextStyle(color: MarketColors.neutral, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - _timeAxisHeight + 4));
    }
  }

  void _drawCrosshair(Canvas canvas, ChartTransform t, double chartWidth, double priceAreaHeight) {
    final p = crosshairPixel!;
    final paint = Paint()
      ..color = MarketColors.neutral
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, priceAreaHeight), paint);
    canvas.drawLine(Offset(0, p.dy), Offset(chartWidth, p.dy), paint);

    final price = t.priceForY(p.dy);
    final label = TextPainter(
      text: TextSpan(
        text: _formatPrice(price),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          backgroundColor: MarketColors.surfaceDarkElevated,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(chartWidth + 6, p.dy - label.height / 2));
  }

  String _formatPrice(double price) {
    if (price >= 1000) return NumberFormat('#,##0').format(price);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(6);
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.candles.length != candles.length ||
        oldDelegate.chartStyle != chartStyle ||
        oldDelegate.firstVisibleIndex != firstVisibleIndex ||
        oldDelegate.visibleCount != visibleCount ||
        oldDelegate.crosshairPixel != crosshairPixel;
  }
}
