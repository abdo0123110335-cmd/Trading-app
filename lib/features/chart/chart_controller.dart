import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/data/repositories/drawing_repository.dart';
import 'package:binance_spot_pro/features/chart/models/chart_types.dart';
import 'package:binance_spot_pro/features/chart/models/drawing_tool.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/heikin_ashi.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_engine.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_settings.dart';
import 'package:binance_spot_pro/services/market_data/market_data_manager.dart';

/// One overlay indicator instance shown on the chart (e.g. EMA 21).
class ChartIndicatorInstance {
  ChartIndicatorInstance({required this.type, required this.settings});
  final IndicatorType type;
  final IndicatorSettings settings;
}

class ChartController extends ChangeNotifier {
  ChartController({
    required MarketDataManager marketDataManager,
    required DrawingRepository drawingRepository,
    required String symbol,
    ChartTimeframe timeframe = ChartTimeframe.default_,
  }) : _marketData = marketDataManager,
       _drawingRepo = drawingRepository,
       symbol = symbol.toUpperCase(),
       _timeframe = timeframe {
    _loadDrawings();
    _subscribeCandles();
  }

  final MarketDataManager _marketData;
  final DrawingRepository _drawingRepo;

  final String symbol;
  ChartTimeframe _timeframe;
  ChartTimeframe get timeframe => _timeframe;

  StreamSubscription<List<Candle>>? _candleSub;
  List<Candle> _rawCandles = [];
  List<Candle> get displayCandles =>
      _chartStyle == ChartStyle.heikinAshi ? toHeikinAshi(_rawCandles) : _rawCandles;
  List<Candle> get rawCandles => _rawCandles;

  bool _loading = true;
  bool get loading => _loading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ChartStyle _chartStyle = ChartStyle.candlestick;
  ChartStyle get chartStyle => _chartStyle;

  // ---- Viewport (pan/zoom) ----
  double firstVisibleIndex = 0;
  double visibleCount = 80;
  static const double _minVisibleCount = 15;
  static const double _maxVisibleCount = 400;

  // ---- Crosshair ----
  Offset? crosshairPixel;

  // ---- Fullscreen ----
  bool isFullscreen = false;

  // ---- Drawing tools ----
  DrawingToolType? activeDrawingTool;
  final List<DrawingObject> drawings = [];
  List<DrawingPoint> inProgressPoints = [];

  // ---- Overlay indicators ----
  final List<ChartIndicatorInstance> overlayIndicators = [
    ChartIndicatorInstance(type: IndicatorType.ema, settings: IndicatorSettings({'length': 21})),
  ];

  Map<IndicatorType, IndicatorResult> get overlayResults {
    final candles = displayCandles;
    return {
      for (final ind in overlayIndicators)
        ind.type: computeIndicator(ind.type, candles, ind.settings),
    };
  }

  void _subscribeCandles() {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    _candleSub?.cancel();
    _candleSub = _marketData.watchCandles(symbol, _timeframe.binanceInterval).listen(
      (candles) {
        _rawCandles = candles;
        _loading = false;
        if (candles.isNotEmpty && visibleCount >= candles.length) {
          visibleCount = candles.length < 80 ? candles.length.toDouble() : 80;
        }
        if (firstVisibleIndex == 0 || firstVisibleIndex + visibleCount > candles.length + 5) {
          firstVisibleIndex = (candles.length - visibleCount).clamp(0, candles.length).toDouble();
        }
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _errorMessage = '$e';
        notifyListeners();
      },
    );
  }

  Future<void> _loadDrawings() async {
    final saved = await _drawingRepo.getDrawings(symbol, _timeframe.binanceInterval);
    drawings
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  void setTimeframe(ChartTimeframe tf) {
    if (tf.binanceInterval == _timeframe.binanceInterval) return;
    _timeframe = tf;
    firstVisibleIndex = 0;
    visibleCount = 80;
    _subscribeCandles();
    _loadDrawings();
  }

  void setChartStyle(ChartStyle style) {
    _chartStyle = style;
    notifyListeners();
  }

  void toggleFullscreen() {
    isFullscreen = !isFullscreen;
    notifyListeners();
  }

  // ---- Pan / zoom ----
  double? _lastWidth;
  void reportCanvasWidth(double width) => _lastWidth = width;

  void panBy(double dxPixels) {
    if (_rawCandles.isEmpty || _lastWidth == null || _lastWidth == 0) return;
    final candleWidth = _lastWidth! / visibleCount;
    if (candleWidth == 0) return;
    firstVisibleIndex -= dxPixels / candleWidth;
    _clampViewport();
    notifyListeners();
  }

  void zoomBy(double scaleFactor, {double? focalX}) {
    if (_rawCandles.isEmpty) return;
    final newVisible = (visibleCount / scaleFactor).clamp(_minVisibleCount, _maxVisibleCount);
    if (focalX != null && _lastWidth != null && _lastWidth! > 0) {
      final focalIndex = firstVisibleIndex + (focalX / _lastWidth!) * visibleCount;
      firstVisibleIndex = focalIndex - (focalX / _lastWidth!) * newVisible;
    }
    visibleCount = newVisible;
    _clampViewport();
    notifyListeners();
  }

  /// Sets an absolute visible-candle count (used by pinch-zoom, which
  /// tracks a cumulative scale from gesture start rather than a per-frame
  /// delta), keeping the given focal x-pixel anchored under the fingers.
  void setVisibleCount(double newCount, {double? focalX}) {
    if (_rawCandles.isEmpty) return;
    final clamped = newCount.clamp(_minVisibleCount, _maxVisibleCount);
    if (focalX != null && _lastWidth != null && _lastWidth! > 0) {
      final focalIndex = firstVisibleIndex + (focalX / _lastWidth!) * visibleCount;
      firstVisibleIndex = focalIndex - (focalX / _lastWidth!) * clamped;
    }
    visibleCount = clamped;
    _clampViewport();
    notifyListeners();
  }

  void _clampViewport() {
    final maxFirst = (_rawCandles.length - visibleCount * 0.2);
    firstVisibleIndex = firstVisibleIndex.clamp(-visibleCount * 0.8, maxFirst < 0 ? 0 : maxFirst);
  }

  // ---- Crosshair ----
  void updateCrosshair(Offset? pixel) {
    crosshairPixel = pixel;
    notifyListeners();
  }

  // ---- Drawing tools ----
  void selectDrawingTool(DrawingToolType? tool) {
    activeDrawingTool = tool;
    inProgressPoints = [];
    notifyListeners();
  }

  Future<void> addDrawingPoint(DrawingPoint point) async {
    final tool = activeDrawingTool;
    if (tool == null) return;
    inProgressPoints = [...inProgressPoints, point];
    if (inProgressPoints.length >= tool.pointsNeeded) {
      final drawing = DrawingObject(
        symbol: symbol,
        timeframe: _timeframe.binanceInterval,
        toolType: tool,
        points: inProgressPoints,
      );
      final id = await _drawingRepo.saveDrawing(drawing);
      drawings.add(drawing.copyWith(id: id));
      inProgressPoints = [];
      activeDrawingTool = null;
    }
    notifyListeners();
  }

  Future<void> deleteDrawing(DrawingObject drawing) async {
    if (drawing.id != null) {
      await _drawingRepo.deleteDrawing(drawing.id!);
    }
    drawings.removeWhere((d) => d.id == drawing.id);
    notifyListeners();
  }

  Future<void> clearAllDrawings() async {
    await _drawingRepo.deleteAllForChart(symbol, _timeframe.binanceInterval);
    drawings.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _candleSub?.cancel();
    super.dispose();
  }
}
