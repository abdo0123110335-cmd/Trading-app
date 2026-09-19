/// Smart Money Concepts data model. All detections carry the candle index
/// they were found at (not just a price) so the Chart screen can plot
/// them precisely and the Signal Engine can reason about recency.
library;

enum SwingType { high, low }

class SwingPoint {
  const SwingPoint({required this.index, required this.price, required this.type});
  final int index;
  final double price;
  final SwingType type;
}

/// HH/HL/LH/LL classification of consecutive swing points — the raw
/// vocabulary of market structure.
enum StructureLabel { higherHigh, higherLow, lowerHigh, lowerLow }

class StructurePoint {
  const StructurePoint({required this.swing, required this.label});
  final SwingPoint swing;
  final StructureLabel label;
}

/// Break of Structure (trend continuation) vs Change of Character (trend
/// reversal warning) — the two market-structure events SMC traders watch.
enum StructureEventType { bos, choch }

enum TrendDirection { bullish, bearish }

class StructureEvent {
  const StructureEvent({
    required this.index,
    required this.price,
    required this.type,
    required this.direction,
  });
  final int index;
  final double price;
  final StructureEventType type;
  final TrendDirection direction;
}

enum OrderBlockType { bullish, bearish }

/// The last opposite-direction candle before a strong impulsive move —
/// the classic SMC "order block" definition.
class OrderBlock {
  const OrderBlock({
    required this.startIndex,
    required this.high,
    required this.low,
    required this.type,
    this.mitigated = false,
  });
  final int startIndex;
  final double high;
  final double low;
  final OrderBlockType type;
  final bool mitigated;

  OrderBlock copyWith({bool? mitigated}) => OrderBlock(
    startIndex: startIndex,
    high: high,
    low: low,
    type: type,
    mitigated: mitigated ?? this.mitigated,
  );
}

enum FvgType { bullish, bearish }

/// A 3-candle imbalance: candle 1 and candle 3 don't overlap, leaving a
/// gap that price tends to revisit ("fill").
class FairValueGap {
  const FairValueGap({
    required this.index,
    required this.top,
    required this.bottom,
    required this.type,
    this.filled = false,
  });
  final int index; // index of the middle (impulse) candle
  final double top;
  final double bottom;
  final FvgType type;
  final bool filled;

  FairValueGap copyWith({bool? filled}) => FairValueGap(
    index: index,
    top: top,
    bottom: bottom,
    type: type,
    filled: filled ?? this.filled,
  );
}

/// Two or more swing highs/lows sitting at (nearly) the same price —
/// resting liquidity the market tends to sweep before reversing.
class EqualLevel {
  const EqualLevel({required this.indices, required this.price, required this.type});
  final List<int> indices;
  final double price;
  final SwingType type; // high => equal highs, low => equal lows
}

/// A wick that pierces beyond a prior swing point and closes back inside
/// — liquidity grabbed, often preceding a reversal.
class LiquiditySweep {
  const LiquiditySweep({
    required this.index,
    required this.sweptLevel,
    required this.type,
  });
  final int index;
  final double sweptLevel;
  final SwingType type; // high => buy-side liquidity swept, low => sell-side
}

enum ZoneType { supply, demand }

class SupplyDemandZone {
  const SupplyDemandZone({
    required this.startIndex,
    required this.high,
    required this.low,
    required this.type,
  });
  final int startIndex;
  final double high;
  final double low;
  final ZoneType type;
}

enum PriceZone { premium, discount, equilibrium }

/// Full SMC read for one candle series, computed once and reused by the
/// Chart overlay, Screener filters and Signal Engine alike.
class SmcAnalysis {
  const SmcAnalysis({
    required this.swingPoints,
    required this.structurePoints,
    required this.structureEvents,
    required this.orderBlocks,
    required this.fairValueGaps,
    required this.equalHighs,
    required this.equalLows,
    required this.liquiditySweeps,
    required this.supplyZones,
    required this.demandZones,
    required this.currentZone,
    required this.currentTrend,
  });

  final List<SwingPoint> swingPoints;
  final List<StructurePoint> structurePoints;
  final List<StructureEvent> structureEvents;
  final List<OrderBlock> orderBlocks;
  final List<FairValueGap> fairValueGaps;
  final List<EqualLevel> equalHighs;
  final List<EqualLevel> equalLows;
  final List<LiquiditySweep> liquiditySweeps;
  final List<SupplyDemandZone> supplyZones;
  final List<SupplyDemandZone> demandZones;
  final PriceZone currentZone;
  final TrendDirection? currentTrend;

  StructureEvent? get lastEvent => structureEvents.isEmpty ? null : structureEvents.last;
  FairValueGap? get nearestUnfilledBullishFvg {
    for (var i = fairValueGaps.length - 1; i >= 0; i--) {
      final f = fairValueGaps[i];
      if (!f.filled && f.type == FvgType.bullish) return f;
    }
    return null;
  }
}
