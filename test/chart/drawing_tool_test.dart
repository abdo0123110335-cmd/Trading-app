import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/features/chart/models/drawing_tool.dart';

void main() {
  group('DrawingToolType.pointsNeeded', () {
    test('single-point tools need exactly 1 tap', () {
      expect(DrawingToolType.horizontalLine.pointsNeeded, 1);
      expect(DrawingToolType.verticalLine.pointsNeeded, 1);
      expect(DrawingToolType.support.pointsNeeded, 1);
      expect(DrawingToolType.resistance.pointsNeeded, 1);
    });

    test('two-point tools need exactly 2 taps', () {
      expect(DrawingToolType.trendLine.pointsNeeded, 2);
      expect(DrawingToolType.ray.pointsNeeded, 2);
      expect(DrawingToolType.rectangle.pointsNeeded, 2);
      expect(DrawingToolType.fibRetracement.pointsNeeded, 2);
      expect(DrawingToolType.priceRange.pointsNeeded, 2);
    });

    test('three-point tools need exactly 3 taps', () {
      expect(DrawingToolType.fibExtension.pointsNeeded, 3);
      expect(DrawingToolType.parallelChannel.pointsNeeded, 3);
    });
  });

  group('DrawingObject', () {
    test('isComplete is false until pointsNeeded is reached', () {
      final incomplete = DrawingObject(
        symbol: 'BTCUSDT',
        timeframe: '1h',
        toolType: DrawingToolType.trendLine,
        points: [DrawingPoint(time: DateTime.utc(2026, 1, 1), price: 100)],
      );
      expect(incomplete.isComplete, isFalse);

      final complete = incomplete.copyWith(
        points: [
          ...incomplete.points,
          DrawingPoint(time: DateTime.utc(2026, 1, 2), price: 110),
        ],
      );
      expect(complete.isComplete, isTrue);
    });

    test('round-trips through JSON encoding for points and style', () {
      final original = DrawingObject(
        symbol: 'ETHUSDT',
        timeframe: '4h',
        toolType: DrawingToolType.rectangle,
        points: [
          DrawingPoint(time: DateTime.utc(2026, 1, 1), price: 2000),
          DrawingPoint(time: DateTime.utc(2026, 1, 2), price: 2100),
        ],
      );
      final decodedPoints = DrawingObject.pointsFromJson(original.pointsJson);
      final decodedStyle = DrawingObject.styleFromJson(original.styleJson);

      expect(decodedPoints.length, 2);
      expect(decodedPoints[0].price, 2000);
      expect(decodedPoints[1].price, 2100);
      expect(decodedStyle.colorValue, original.style.colorValue);
    });
  });
}
