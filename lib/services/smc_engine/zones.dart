import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';

/// Derives Supply/Demand zones directly from order blocks — an
/// unmitigated bullish order block IS a demand zone (price is expected to
/// react upward from it), and a bearish order block IS a supply zone.
/// Keeping this as a thin derivation (rather than a separate detector)
/// avoids the two concepts silently disagreeing with each other.
List<SupplyDemandZone> zonesFromOrderBlocks(List<OrderBlock> blocks) {
  return blocks
      .where((b) => !b.mitigated)
      .map(
        (b) => SupplyDemandZone(
          startIndex: b.startIndex,
          high: b.high,
          low: b.low,
          type: b.type == OrderBlockType.bullish ? ZoneType.demand : ZoneType.supply,
        ),
      )
      .toList();
}

/// Classifies the current price within the most recent significant
/// swing-high-to-swing-low range: top 50% = premium (favor selling/less
/// attractive to buy), bottom 50% = discount (favor buying), the exact
/// midpoint band = equilibrium.
PriceZone classifyPremiumDiscount(
  double currentPrice,
  SwingPoint? recentHigh,
  SwingPoint? recentLow, {
  double equilibriumBandPct = 0.05,
}) {
  if (recentHigh == null || recentLow == null || recentHigh.price <= recentLow.price) {
    return PriceZone.equilibrium;
  }
  final range = recentHigh.price - recentLow.price;
  final position = (currentPrice - recentLow.price) / range; // 0 = low, 1 = high
  final midLow = 0.5 - equilibriumBandPct;
  final midHigh = 0.5 + equilibriumBandPct;

  if (position >= midLow && position <= midHigh) return PriceZone.equilibrium;
  return position > 0.5 ? PriceZone.premium : PriceZone.discount;
}
