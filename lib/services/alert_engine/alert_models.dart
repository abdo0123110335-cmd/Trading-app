/// Every alert type the spec's Alert System asks for.
enum AlertType {
  price,
  rsi,
  emaCross,
  macdCross,
  volumeSpike,
  breakout,
  supportBreak,
  resistanceBreak,
  bos,
  choch,
  fvg,
  smcSignal,
  buySignal,
  scoreThreshold,
}

extension AlertTypeLabel on AlertType {
  String get label {
    switch (this) {
      case AlertType.price:
        return 'Price';
      case AlertType.rsi:
        return 'RSI';
      case AlertType.emaCross:
        return 'EMA Cross';
      case AlertType.macdCross:
        return 'MACD Cross';
      case AlertType.volumeSpike:
        return 'Volume Spike';
      case AlertType.breakout:
        return 'Breakout';
      case AlertType.supportBreak:
        return 'Support Break';
      case AlertType.resistanceBreak:
        return 'Resistance Break';
      case AlertType.bos:
        return 'BOS';
      case AlertType.choch:
        return 'CHoCH';
      case AlertType.fvg:
        return 'FVG';
      case AlertType.smcSignal:
        return 'SMC Signal';
      case AlertType.buySignal:
        return 'BUY Signal';
      case AlertType.scoreThreshold:
        return 'Score Threshold';
    }
  }

  /// Whether this alert type needs an operator + numeric value (price,
  /// RSI, score) versus firing purely on an event happening (everything
  /// else — crosses, spikes, structure events).
  bool get needsThreshold =>
      this == AlertType.price || this == AlertType.rsi || this == AlertType.scoreThreshold;
}

enum ComparisonOperator { greaterThan, lessThan, greaterOrEqual, lessOrEqual }

extension ComparisonOperatorSymbol on ComparisonOperator {
  String get symbol {
    switch (this) {
      case ComparisonOperator.greaterThan:
        return '>';
      case ComparisonOperator.lessThan:
        return '<';
      case ComparisonOperator.greaterOrEqual:
        return '>=';
      case ComparisonOperator.lessOrEqual:
        return '<=';
    }
  }

  bool compare(double left, double right) {
    switch (this) {
      case ComparisonOperator.greaterThan:
        return left > right;
      case ComparisonOperator.lessThan:
        return left < right;
      case ComparisonOperator.greaterOrEqual:
        return left >= right;
      case ComparisonOperator.lessOrEqual:
        return left <= right;
    }
  }
}

/// Decoded form of an alert row's `conditionJson`. Threshold alerts carry
/// [operator]/[value] (e.g. "BTCUSDT > 100000", "RSI < 30"); event alerts
/// leave them null and just fire when the underlying event is detected.
class AlertCondition {
  const AlertCondition({this.operator, this.value});

  final ComparisonOperator? operator;
  final double? value;

  Map<String, dynamic> toJson() => {
    'operator': operator?.name,
    'value': value,
  };

  factory AlertCondition.fromJson(Map<String, dynamic> json) {
    final opName = json['operator'] as String?;
    return AlertCondition(
      operator: opName == null
          ? null
          : ComparisonOperator.values.firstWhere((o) => o.name == opName),
      value: (json['value'] as num?)?.toDouble(),
    );
  }
}
