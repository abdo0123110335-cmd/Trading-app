import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:binance_spot_pro/features/chart/chart_controller.dart';
import 'package:binance_spot_pro/features/chart/models/chart_transform.dart';
import 'package:binance_spot_pro/features/chart/models/drawing_tool.dart';
import 'package:binance_spot_pro/features/chart/widgets/chart_painter.dart';
import 'package:binance_spot_pro/features/chart/widgets/drawing_painter.dart';

/// The tappable/pannable/zoomable chart surface. Supports:
///   * One-finger drag → pan (via [GestureDetector.onScaleUpdate], which
///     Flutter also uses for pinch, so pan+zoom share one recognizer and
///     never fight each other).
///   * Two-finger pinch → zoom, focal-point aware so the point under your
///     fingers stays under your fingers.
///   * Long-press + drag → crosshair.
///   * Tap, while a drawing tool is active → places the next anchor point.
class ChartCanvas extends StatefulWidget {
  const ChartCanvas({super.key});

  @override
  State<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends State<ChartCanvas> {
  double _scaleStartVisibleCount = 80;
  Offset? _lastFocalPoint;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChartController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        const priceAxisWidth = 64.0;
        final chartWidth = constraints.maxWidth - priceAxisWidth;
        controller.reportCanvasWidth(chartWidth);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _scaleStartVisibleCount = controller.visibleCount;
            _lastFocalPoint = details.localFocalPoint;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount >= 2) {
              final newCount = (_scaleStartVisibleCount / details.scale).clamp(15.0, 400.0);
              controller.setVisibleCount(newCount, focalX: details.localFocalPoint.dx);
            } else if (_lastFocalPoint != null) {
              final dx = details.localFocalPoint.dx - _lastFocalPoint!.dx;
              controller.panBy(dx);
              _lastFocalPoint = details.localFocalPoint;
            }
          },
          onLongPressStart: (details) => controller.updateCrosshair(details.localPosition),
          onLongPressMoveUpdate: (details) => controller.updateCrosshair(details.localPosition),
          onLongPressEnd: (_) => controller.updateCrosshair(null),
          onTapUp: (details) => _handleTap(context, controller, details.localPosition, chartWidth),
          child: MouseRegion(
            cursor: controller.activeDrawingTool != null
                ? SystemMouseCursors.precise
                : MouseCursor.defer,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: ChartPainter(
                candles: controller.displayCandles,
                chartStyle: controller.chartStyle,
                firstVisibleIndex: controller.firstVisibleIndex,
                visibleCount: controller.visibleCount,
                overlays: controller.overlayResults,
                crosshairPixel: controller.crosshairPixel,
              ),
              foregroundPainter: DrawingPainter(
                candles: controller.displayCandles,
                firstVisibleIndex: controller.firstVisibleIndex,
                visibleCount: controller.visibleCount,
                priceAreaHeight: constraints.maxHeight * 0.82 - 22,
                chartWidth: chartWidth,
                drawings: controller.drawings,
                inProgressTool: controller.activeDrawingTool,
                inProgressPoints: controller.inProgressPoints,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(
    BuildContext context,
    ChartController controller,
    Offset localPosition,
    double chartWidth,
  ) {
    if (controller.activeDrawingTool == null) return;
    if (controller.displayCandles.isEmpty) return;

    final priceAreaHeight = MediaQuery.of(context).size.height * 0.82 - 22;
    final transform = ChartTransform(
      candles: controller.displayCandles,
      firstVisibleIndex: controller.firstVisibleIndex,
      visibleCount: controller.visibleCount,
      width: chartWidth,
      priceAreaHeight: priceAreaHeight,
    );

    final index = transform.indexForX(localPosition.dx).round().clamp(
      0,
      controller.displayCandles.length - 1,
    );
    final price = transform.priceForY(localPosition.dy);
    final time = controller.displayCandles[index].openTime;

    controller.addDrawingPoint(DrawingPoint(time: time, price: price));
  }
}
