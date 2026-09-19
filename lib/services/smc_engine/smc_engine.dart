import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/smc_engine/fair_value_gaps.dart';
import 'package:binance_spot_pro/services/smc_engine/liquidity.dart';
import 'package:binance_spot_pro/services/smc_engine/market_structure.dart';
import 'package:binance_spot_pro/services/smc_engine/order_blocks.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';
import 'package:binance_spot_pro/services/smc_engine/swing_points.dart';
import 'package:binance_spot_pro/services/smc_engine/zones.dart';

/// Single entry point for the whole SMC pipeline: swing points → market
/// structure (HH/HL/LH/LL, BOS/CHoCH) → order blocks → FVGs → liquidity
/// (equal highs/lows, sweeps) → supply/demand zones → premium/discount.
///
/// Used identically by the Chart screen's SMC overlay, the Screener's SMC
/// filters, and the Signal Engine's SMC score component — one analysis,
/// three consumers, so they can never disagree with each other.
SmcAnalysis analyzeSmc(List<Candle> candles, {int swingStrength = 2}) {
  if (candles.length < swingStrength * 2 + 3) {
    return const SmcAnalysis(
      swingPoints: [],
      structurePoints: [],
      structureEvents: [],
      orderBlocks: [],
      fairValueGaps: [],
      equalHighs: [],
      equalLows: [],
      liquiditySweeps: [],
      supplyZones: [],
      demandZones: [],
      currentZone: PriceZone.equilibrium,
      currentTrend: null,
    );
  }

  final closes = candles.map((c) => c.close).toList();

  final swings = detectSwingPoints(candles, strength: swingStrength);
  final structurePoints = classifyStructure(swings);
  final structureEvents = detectStructureEvents(swings, closes);
  final orderBlocks = detectOrderBlocks(candles);
  final fvgs = detectFairValueGaps(candles);
  final equalHighs = detectEqualLevels(swings, SwingType.high);
  final equalLows = detectEqualLevels(swings, SwingType.low);
  final sweeps = detectLiquiditySweeps(candles, swings);
  final zones = zonesFromOrderBlocks(orderBlocks);

  SwingPoint? recentHigh;
  SwingPoint? recentLow;
  for (var i = swings.length - 1; i >= 0; i--) {
    if (recentHigh == null && swings[i].type == SwingType.high) recentHigh = swings[i];
    if (recentLow == null && swings[i].type == SwingType.low) recentLow = swings[i];
    if (recentHigh != null && recentLow != null) break;
  }

  final currentZone = classifyPremiumDiscount(closes.last, recentHigh, recentLow);
  final currentTrend = structureEvents.isEmpty ? null : structureEvents.last.direction;

  return SmcAnalysis(
    swingPoints: swings,
    structurePoints: structurePoints,
    structureEvents: structureEvents,
    orderBlocks: orderBlocks,
    fairValueGaps: fvgs,
    equalHighs: equalHighs,
    equalLows: equalLows,
    liquiditySweeps: sweeps,
    supplyZones: zones.where((z) => z.type == ZoneType.supply).toList(),
    demandZones: zones.where((z) => z.type == ZoneType.demand).toList(),
    currentZone: currentZone,
    currentTrend: currentTrend,
  );
}
