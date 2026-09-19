enum TpCloseMode { closeAtTp1, closeAtTp2, custom }

class EntrySlTpInput {
  const EntrySlTpInput({
    required this.entry,
    required this.stopLoss,
    required this.accountRiskUsdt,
    this.tp1Multiplier = 1.5,
    this.tp2Multiplier = 3.0,
    this.closeMode = TpCloseMode.closeAtTp1,
    this.closeHalfAtTp1 = false,
  });

  final double entry;
  final double stopLoss;

  /// How much USDT the user is willing to lose if the stop is hit — the
  /// standalone tool's "Risk" input.
  final double accountRiskUsdt;
  final double tp1Multiplier;
  final double tp2Multiplier;
  final TpCloseMode closeMode;

  /// "Close 50% at TP1" toggle from the spec.
  final bool closeHalfAtTp1;
}

class EntrySlTpResult {
  const EntrySlTpResult({
    required this.riskAmount,
    required this.riskPercent,
    required this.positionSize,
    required this.tp1,
    required this.tp2,
    required this.riskRewardTp1,
    required this.riskRewardTp2,
    required this.isLong,
  });

  final double riskAmount;

  /// Risk expressed as % of entry price (distance to stop / entry).
  final double riskPercent;

  /// Position size in base-asset units implied by riskAmount / per-unit
  /// risk — how many coins to buy so a stop-out costs exactly
  /// [riskAmount].
  final double positionSize;
  final double tp1;
  final double tp2;
  final double riskRewardTp1;
  final double riskRewardTp2;
  final bool isLong;
}

/// Pure calculator — no Binance/DB dependency, so it works identically
/// whether or not the user has connected an account, and whether or not
/// Live Trading is enabled. Spot-only: [EntrySlTpInput.stopLoss] is
/// always assumed to be *below* entry (a long position) since the app
/// never supports shorting.
EntrySlTpResult calculateEntrySlTp(EntrySlTpInput input) {
  final perUnitRisk = (input.entry - input.stopLoss).abs();
  final riskPercent = input.entry == 0 ? 0.0 : (perUnitRisk / input.entry) * 100;
  final positionSize = perUnitRisk == 0 ? 0.0 : input.accountRiskUsdt / perUnitRisk;

  final isLong = input.entry > input.stopLoss;
  final tp1 = isLong
      ? input.entry + perUnitRisk * input.tp1Multiplier
      : input.entry - perUnitRisk * input.tp1Multiplier;
  final tp2 = isLong
      ? input.entry + perUnitRisk * input.tp2Multiplier
      : input.entry - perUnitRisk * input.tp2Multiplier;

  return EntrySlTpResult(
    riskAmount: input.accountRiskUsdt,
    riskPercent: riskPercent,
    positionSize: positionSize,
    tp1: tp1,
    tp2: tp2,
    riskRewardTp1: input.tp1Multiplier,
    riskRewardTp2: input.tp2Multiplier,
    isLong: isLong,
  );
}
