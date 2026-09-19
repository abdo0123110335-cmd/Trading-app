import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';

/// The named setups the Market Scanner section of the spec asks for,
/// beyond the base BUY/HOLD/EXIT signal.
enum ScanSetupTag {
  oversold,
  buySetup,
  breakout,
  volumeSpike,
  fvg,
  bos,
  choch,
  supportBounce,
  emaCross,
}

extension ScanSetupTagLabel on ScanSetupTag {
  String get label {
    switch (this) {
      case ScanSetupTag.oversold:
        return 'Oversold';
      case ScanSetupTag.buySetup:
        return 'BUY Setup';
      case ScanSetupTag.breakout:
        return 'Breakout';
      case ScanSetupTag.volumeSpike:
        return 'Volume Spike';
      case ScanSetupTag.fvg:
        return 'FVG';
      case ScanSetupTag.bos:
        return 'BOS';
      case ScanSetupTag.choch:
        return 'CHoCH';
      case ScanSetupTag.supportBounce:
        return 'Support Bounce';
      case ScanSetupTag.emaCross:
        return 'EMA Cross';
    }
  }
}

/// One symbol's full scan output: the underlying signal plus every setup
/// tag that matched, and the raw values a Screener filter/sort needs
/// (RSI, relative volume, ATR) without recomputing them.
class ScanResult {
  const ScanResult({
    required this.symbol,
    required this.signal,
    required this.tags,
    required this.rsi,
    required this.relativeVolume,
    required this.atr,
    required this.priceChangePercent,
  });

  final String symbol;
  final SignalResult signal;
  final Set<ScanSetupTag> tags;
  final double? rsi;
  final double? relativeVolume;
  final double? atr;
  final double priceChangePercent;
}
