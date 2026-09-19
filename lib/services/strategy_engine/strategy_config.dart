/// A fully-typed view of one strategy's settings (persisted as loose
/// key/value rows in `strategy_settings`, per the DB schema, so new
/// filters can be added later without a migration).
class StrategyConfig {
  const StrategyConfig({
    required this.strategyId,
    required this.name,
    this.rsiLength = 6,
    this.rsiOversold = 30,
    this.rsiOverbought = 70,
    this.filterEmaEnabled = false,
    this.filterVolumeEnabled = false,
    this.filterMacdEnabled = false,
    this.filterTrendEnabled = false,
    this.filterSupportEnabled = false,
    this.filterSmcEnabled = false,
    this.minBuyScore = 75,
    this.weightRsi = 20,
    this.weightEma = 15,
    this.weightMacd = 15,
    this.weightVolume = 15,
    this.weightTrend = 10,
    this.weightSmc = 15,
    this.weightSupport = 10,
  });

  final int strategyId;
  final String name;

  final int rsiLength;
  final double rsiOversold;
  final double rsiOverbought;

  final bool filterEmaEnabled;
  final bool filterVolumeEnabled;
  final bool filterMacdEnabled;
  final bool filterTrendEnabled;
  final bool filterSupportEnabled;
  final bool filterSmcEnabled;

  final int minBuyScore;

  // Score weights — sum should equal 100 for the 0-100 Score System, but
  // this isn't force-normalized here so the user can experiment with
  // custom weightings from Settings > Strategy Settings.
  final double weightRsi;
  final double weightEma;
  final double weightMacd;
  final double weightVolume;
  final double weightTrend;
  final double weightSmc;
  final double weightSupport;

  Map<String, String> toSettingsMap() => {
    'rsi_length': '$rsiLength',
    'rsi_oversold': '$rsiOversold',
    'rsi_overbought': '$rsiOverbought',
    'filter_ema_enabled': '$filterEmaEnabled',
    'filter_volume_enabled': '$filterVolumeEnabled',
    'filter_macd_enabled': '$filterMacdEnabled',
    'filter_trend_enabled': '$filterTrendEnabled',
    'filter_support_enabled': '$filterSupportEnabled',
    'filter_smc_enabled': '$filterSmcEnabled',
    'min_buy_score': '$minBuyScore',
    'weight_rsi': '$weightRsi',
    'weight_ema': '$weightEma',
    'weight_macd': '$weightMacd',
    'weight_volume': '$weightVolume',
    'weight_trend': '$weightTrend',
    'weight_smc': '$weightSmc',
    'weight_support': '$weightSupport',
  };

  static StrategyConfig fromSettingsMap(
    int strategyId,
    String name,
    Map<String, String> settings,
  ) {
    double d(String key, double fallback) => double.tryParse(settings[key] ?? '') ?? fallback;
    int i(String key, int fallback) => int.tryParse(settings[key] ?? '') ?? fallback;
    bool b(String key, bool fallback) =>
        settings[key] == null ? fallback : settings[key] == 'true';

    return StrategyConfig(
      strategyId: strategyId,
      name: name,
      rsiLength: i('rsi_length', 6),
      rsiOversold: d('rsi_oversold', 30),
      rsiOverbought: d('rsi_overbought', 70),
      filterEmaEnabled: b('filter_ema_enabled', false),
      filterVolumeEnabled: b('filter_volume_enabled', false),
      filterMacdEnabled: b('filter_macd_enabled', false),
      filterTrendEnabled: b('filter_trend_enabled', false),
      filterSupportEnabled: b('filter_support_enabled', false),
      filterSmcEnabled: b('filter_smc_enabled', false),
      minBuyScore: i('min_buy_score', 75),
      weightRsi: d('weight_rsi', 20),
      weightEma: d('weight_ema', 15),
      weightMacd: d('weight_macd', 15),
      weightVolume: d('weight_volume', 15),
      weightTrend: d('weight_trend', 10),
      weightSmc: d('weight_smc', 15),
      weightSupport: d('weight_support', 10),
    );
  }

  StrategyConfig copyWith({
    int? rsiLength,
    double? rsiOversold,
    double? rsiOverbought,
    bool? filterEmaEnabled,
    bool? filterVolumeEnabled,
    bool? filterMacdEnabled,
    bool? filterTrendEnabled,
    bool? filterSupportEnabled,
    bool? filterSmcEnabled,
    int? minBuyScore,
    double? weightRsi,
    double? weightEma,
    double? weightMacd,
    double? weightVolume,
    double? weightTrend,
    double? weightSmc,
    double? weightSupport,
  }) {
    return StrategyConfig(
      strategyId: strategyId,
      name: name,
      rsiLength: rsiLength ?? this.rsiLength,
      rsiOversold: rsiOversold ?? this.rsiOversold,
      rsiOverbought: rsiOverbought ?? this.rsiOverbought,
      filterEmaEnabled: filterEmaEnabled ?? this.filterEmaEnabled,
      filterVolumeEnabled: filterVolumeEnabled ?? this.filterVolumeEnabled,
      filterMacdEnabled: filterMacdEnabled ?? this.filterMacdEnabled,
      filterTrendEnabled: filterTrendEnabled ?? this.filterTrendEnabled,
      filterSupportEnabled: filterSupportEnabled ?? this.filterSupportEnabled,
      filterSmcEnabled: filterSmcEnabled ?? this.filterSmcEnabled,
      minBuyScore: minBuyScore ?? this.minBuyScore,
      weightRsi: weightRsi ?? this.weightRsi,
      weightEma: weightEma ?? this.weightEma,
      weightMacd: weightMacd ?? this.weightMacd,
      weightVolume: weightVolume ?? this.weightVolume,
      weightTrend: weightTrend ?? this.weightTrend,
      weightSmc: weightSmc ?? this.weightSmc,
      weightSupport: weightSupport ?? this.weightSupport,
    );
  }
}
