import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';

/// Labels each swing point HH/HL/LH/LL relative to the previous swing of
/// the same type (high vs. high, low vs. low).
List<StructurePoint> classifyStructure(List<SwingPoint> swings) {
  final out = <StructurePoint>[];
  SwingPoint? prevHigh;
  SwingPoint? prevLow;

  for (final s in swings) {
    if (s.type == SwingType.high) {
      if (prevHigh != null) {
        out.add(
          StructurePoint(
            swing: s,
            label: s.price > prevHigh.price ? StructureLabel.higherHigh : StructureLabel.lowerHigh,
          ),
        );
      }
      prevHigh = s;
    } else {
      if (prevLow != null) {
        out.add(
          StructurePoint(
            swing: s,
            label: s.price > prevLow.price ? StructureLabel.higherLow : StructureLabel.lowerLow,
          ),
        );
      }
      prevLow = s;
    }
  }
  return out;
}

/// Walks closes against the most recent confirmed swing high/low to
/// detect:
///   * BOS (Break of Structure) — price closes beyond the last swing in
///     the direction of the *existing* trend → trend continuation.
///   * CHoCH (Change of Character) — price closes beyond the last swing
///     *against* the existing trend → the first warning of a reversal.
///
/// `closes`/`closeIndices` let this run against either raw closes or any
/// other confirmation series without re-deriving swings.
List<StructureEvent> detectStructureEvents(
  List<SwingPoint> swings,
  List<double> closes,
) {
  final events = <StructureEvent>[];
  if (swings.isEmpty) return events;

  TrendDirection? trend;
  SwingPoint? lastHigh;
  SwingPoint? lastLow;

  // Walk swings in chronological order, and for each swing, check whether
  // any close *after* this swing (and before the next swing of the same
  // type) broke through it.
  for (var s = 0; s < swings.length; s++) {
    final swing = swings[s];
    if (swing.type == SwingType.high) {
      lastHigh = swing;
    } else {
      lastLow = swing;
    }

    final nextSameTypeIndex = _nextIndexOfType(swings, s, swing.type);
    final scanEnd = nextSameTypeIndex ?? closes.length;

    for (var i = swing.index + 1; i < scanEnd && i < closes.length; i++) {
      if (swing.type == SwingType.high && closes[i] > swing.price) {
        final isContinuation = trend == TrendDirection.bullish;
        events.add(
          StructureEvent(
            index: i,
            price: swing.price,
            type: isContinuation ? StructureEventType.bos : StructureEventType.choch,
            direction: TrendDirection.bullish,
          ),
        );
        trend = TrendDirection.bullish;
        break;
      } else if (swing.type == SwingType.low && closes[i] < swing.price) {
        final isContinuation = trend == TrendDirection.bearish;
        events.add(
          StructureEvent(
            index: i,
            price: swing.price,
            type: isContinuation ? StructureEventType.bos : StructureEventType.choch,
            direction: TrendDirection.bearish,
          ),
        );
        trend = TrendDirection.bearish;
        break;
      }
    }
  }

  return events;
}

int? _nextIndexOfType(List<SwingPoint> swings, int fromExclusive, SwingType type) {
  for (var i = fromExclusive + 1; i < swings.length; i++) {
    if (swings[i].type == type) return swings[i].index;
  }
  return null;
}
