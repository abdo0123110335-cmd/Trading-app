import 'package:flutter/material.dart';

import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/features/chart/models/chart_transform.dart';
import 'package:binance_spot_pro/features/chart/models/drawing_tool.dart';

class DrawingPainter extends CustomPainter {
  DrawingPainter({
    required this.candles,
    required this.firstVisibleIndex,
    required this.visibleCount,
    required this.priceAreaHeight,
    required this.chartWidth,
    required this.drawings,
    required this.inProgressTool,
    required this.inProgressPoints,
    this.liveCursor,
  });

  final List<Candle> candles;
  final double firstVisibleIndex;
  final double visibleCount;
  final double priceAreaHeight;
  final double chartWidth;
  final List<DrawingObject> drawings;
  final DrawingToolType? inProgressTool;
  final List<DrawingPoint> inProgressPoints;
  final Offset? liveCursor;

  static const fibLevels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final t = ChartTransform(
      candles: candles,
      firstVisibleIndex: firstVisibleIndex,
      visibleCount: visibleCount,
      width: chartWidth,
      priceAreaHeight: priceAreaHeight,
    );

    for (final d in drawings) {
      _drawOne(canvas, t, d.toolType, _toPixels(t, d.points), Color(d.style.colorValue));
    }

    if (inProgressTool != null && inProgressPoints.isNotEmpty) {
      final pixels = _toPixels(t, inProgressPoints);
      if (liveCursor != null) pixels.add(liveCursor!);
      _drawOne(canvas, t, inProgressTool!, pixels, MarketColors.warning, isPreview: true);
    }
  }

  List<Offset> _toPixels(ChartTransform t, List<DrawingPoint> points) {
    return points.map((p) {
      final index = _timeToIndex(p.time);
      return Offset(t.xForIndex(index) + t.candleWidth / 2, t.yForPrice(p.price));
    }).toList();
  }

  double _timeToIndex(DateTime time) {
    // Nearest candle by openTime; falls back to extrapolation for
    // horizontal/vertical lines anchored slightly outside loaded history.
    if (candles.isEmpty) return 0;
    var closest = 0;
    var bestDiff = (candles[0].openTime.difference(time)).abs();
    for (var i = 1; i < candles.length; i++) {
      final diff = (candles[i].openTime.difference(time)).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        closest = i;
      }
    }
    return closest.toDouble();
  }

  void _drawOne(
    Canvas canvas,
    ChartTransform t,
    DrawingToolType tool,
    List<Offset> pixels,
    Color color, {
    bool isPreview = false,
  }) {
    if (pixels.isEmpty) return;
    final linePaint = Paint()
      ..color = isPreview ? color.withValues(alpha: 0.8) : color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = color.withValues(alpha: 0.12);

    switch (tool) {
      case DrawingToolType.horizontalLine:
      case DrawingToolType.support:
      case DrawingToolType.resistance:
        final y = pixels.first.dy;
        canvas.drawLine(Offset(0, y), Offset(t.width, y), linePaint);

      case DrawingToolType.verticalLine:
        final x = pixels.first.dx;
        canvas.drawLine(Offset(x, 0), Offset(x, t.priceAreaHeight), linePaint);

      case DrawingToolType.trendLine:
        if (pixels.length >= 2) canvas.drawLine(pixels[0], pixels[1], linePaint);

      case DrawingToolType.ray:
        if (pixels.length >= 2) {
          final p0 = pixels[0];
          final p1 = pixels[1];
          final dir = (p1 - p0);
          if (dir.distance > 0) {
            final extended = p0 + dir * (t.width / dir.distance.clamp(1, t.width));
            canvas.drawLine(p0, extended, linePaint);
          }
        }

      case DrawingToolType.rectangle:
      case DrawingToolType.priceRange:
        if (pixels.length >= 2) {
          final rect = Rect.fromPoints(pixels[0], pixels[1]);
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, linePaint);
        }

      case DrawingToolType.fibRetracement:
        if (pixels.length >= 2) {
          _drawFib(canvas, t, pixels[0], pixels[1], linePaint, extension: false);
        }

      case DrawingToolType.fibExtension:
        if (pixels.length >= 3) {
          _drawFib(canvas, t, pixels[0], pixels[1], linePaint, extension: true, thirdPoint: pixels[2]);
        }

      case DrawingToolType.parallelChannel:
        if (pixels.length >= 2) {
          canvas.drawLine(pixels[0], pixels[1], linePaint);
          if (pixels.length >= 3) {
            final offsetVec = pixels[2] - pixels[1];
            canvas.drawLine(pixels[0] + offsetVec, pixels[1] + offsetVec, linePaint);
          }
        }
    }

    for (final p in pixels) {
      canvas.drawCircle(p, 3, Paint()..color = color);
    }
  }

  void _drawFib(
    Canvas canvas,
    ChartTransform t,
    Offset p0,
    Offset p1,
    Paint linePaint, {
    required bool extension,
    Offset? thirdPoint,
  }) {
    final priceStart = t.priceForY(p0.dy);
    final priceEnd = t.priceForY(p1.dy);
    final diff = priceEnd - priceStart;
    for (final level in fibLevels) {
      final price = extension
          ? priceEnd + diff * level
          : priceStart + diff * (1 - level);
      final y = t.yForPrice(price);
      canvas.drawLine(Offset(0, y), Offset(t.width, y), linePaint..strokeWidth = 1);
      final tp = TextPainter(
        text: TextSpan(
          text: '${(level * 100).toStringAsFixed(1)}%',
          style: const TextStyle(color: MarketColors.neutral, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, y - tp.height - 1));
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
