import 'dart:convert';

/// All 11 drawing tools from the spec. `pointsNeeded` drives the toolbar's
/// "tap N points to finish" flow in the Chart screen.
enum DrawingToolType {
  trendLine,
  horizontalLine,
  verticalLine,
  ray,
  rectangle,
  fibRetracement,
  fibExtension,
  parallelChannel,
  priceRange,
  support,
  resistance,
}

extension DrawingToolMeta on DrawingToolType {
  String get label {
    switch (this) {
      case DrawingToolType.trendLine:
        return 'Trend Line';
      case DrawingToolType.horizontalLine:
        return 'Horizontal Line';
      case DrawingToolType.verticalLine:
        return 'Vertical Line';
      case DrawingToolType.ray:
        return 'Ray';
      case DrawingToolType.rectangle:
        return 'Rectangle';
      case DrawingToolType.fibRetracement:
        return 'Fib Retracement';
      case DrawingToolType.fibExtension:
        return 'Fib Extension';
      case DrawingToolType.parallelChannel:
        return 'Parallel Channel';
      case DrawingToolType.priceRange:
        return 'Price Range';
      case DrawingToolType.support:
        return 'Support';
      case DrawingToolType.resistance:
        return 'Resistance';
    }
  }

  /// How many chart taps this tool needs before it's committed.
  int get pointsNeeded {
    switch (this) {
      case DrawingToolType.horizontalLine:
      case DrawingToolType.verticalLine:
      case DrawingToolType.support:
      case DrawingToolType.resistance:
        return 1;
      case DrawingToolType.trendLine:
      case DrawingToolType.ray:
      case DrawingToolType.rectangle:
      case DrawingToolType.fibRetracement:
      case DrawingToolType.priceRange:
        return 2;
      case DrawingToolType.fibExtension:
      case DrawingToolType.parallelChannel:
        return 3;
    }
  }
}

/// A single anchor point in chart-data space (not pixel space) so drawings
/// stay correctly positioned across zoom/pan and app restarts.
class DrawingPoint {
  const DrawingPoint({required this.time, required this.price});
  final DateTime time;
  final double price;

  Map<String, dynamic> toJson() => {
    'time': time.millisecondsSinceEpoch,
    'price': price,
  };

  factory DrawingPoint.fromJson(Map<String, dynamic> json) => DrawingPoint(
    time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
    price: (json['price'] as num).toDouble(),
  );
}

class DrawingStyle {
  const DrawingStyle({this.colorValue = 0xFF2962FF, this.strokeWidth = 1.5});
  final int colorValue; // ARGB int, avoids a Flutter Color import here
  final double strokeWidth;

  Map<String, dynamic> toJson() => {'color': colorValue, 'strokeWidth': strokeWidth};

  factory DrawingStyle.fromJson(Map<String, dynamic> json) => DrawingStyle(
    colorValue: json['color'] as int? ?? 0xFF2962FF,
    strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.5,
  );
}

/// One saved (or in-progress) drawing object on a symbol+timeframe chart.
class DrawingObject {
  const DrawingObject({
    this.id,
    required this.symbol,
    required this.timeframe,
    required this.toolType,
    required this.points,
    this.style = const DrawingStyle(),
  });

  final int? id;
  final String symbol;
  final String timeframe;
  final DrawingToolType toolType;
  final List<DrawingPoint> points;
  final DrawingStyle style;

  bool get isComplete => points.length >= toolType.pointsNeeded;

  DrawingObject copyWith({int? id, List<DrawingPoint>? points, DrawingStyle? style}) {
    return DrawingObject(
      id: id ?? this.id,
      symbol: symbol,
      timeframe: timeframe,
      toolType: toolType,
      points: points ?? this.points,
      style: style ?? this.style,
    );
  }

  String get pointsJson => jsonEncode(points.map((p) => p.toJson()).toList());
  String get styleJson => jsonEncode(style.toJson());

  static List<DrawingPoint> pointsFromJson(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => DrawingPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  static DrawingStyle styleFromJson(String json) {
    return DrawingStyle.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}
