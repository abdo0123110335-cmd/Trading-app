import 'package:binance_spot_pro/data/repositories/settings_repository.dart';

class RiskConfig {
  const RiskConfig({
    this.maxTradeAmountUsdt = 100,
    this.maxPositionSizeUsdt = 500,
    this.maxOpenOrders = 5,
    this.maxDailyRiskUsdt = 50,
    this.defaultStopLossPct = 2.0,
    this.defaultTakeProfitPct = 4.0,
    this.emergencyStopActive = false,
  });

  final double maxTradeAmountUsdt;
  final double maxPositionSizeUsdt;
  final int maxOpenOrders;
  final double maxDailyRiskUsdt;
  final double defaultStopLossPct;
  final double defaultTakeProfitPct;
  final bool emergencyStopActive;

  RiskConfig copyWith({
    double? maxTradeAmountUsdt,
    double? maxPositionSizeUsdt,
    int? maxOpenOrders,
    double? maxDailyRiskUsdt,
    double? defaultStopLossPct,
    double? defaultTakeProfitPct,
    bool? emergencyStopActive,
  }) {
    return RiskConfig(
      maxTradeAmountUsdt: maxTradeAmountUsdt ?? this.maxTradeAmountUsdt,
      maxPositionSizeUsdt: maxPositionSizeUsdt ?? this.maxPositionSizeUsdt,
      maxOpenOrders: maxOpenOrders ?? this.maxOpenOrders,
      maxDailyRiskUsdt: maxDailyRiskUsdt ?? this.maxDailyRiskUsdt,
      defaultStopLossPct: defaultStopLossPct ?? this.defaultStopLossPct,
      defaultTakeProfitPct: defaultTakeProfitPct ?? this.defaultTakeProfitPct,
      emergencyStopActive: emergencyStopActive ?? this.emergencyStopActive,
    );
  }
}

class RiskCheckFailure {
  const RiskCheckFailure(this.reason);
  final String reason;
}

class RiskKeys {
  RiskKeys._();
  static const maxTradeAmount = 'risk_max_trade_amount_usdt';
  static const maxPositionSize = 'risk_max_position_size_usdt';
  static const maxOpenOrders = 'risk_max_open_orders';
  static const maxDailyRisk = 'risk_max_daily_risk_usdt';
  static const defaultStopLossPct = 'risk_default_sl_pct';
  static const defaultTakeProfitPct = 'risk_default_tp_pct';
  static const emergencyStop = 'risk_emergency_stop_active';
  static const dailyRiskUsedDate = 'risk_daily_used_date';
  static const dailyRiskUsedAmount = 'risk_daily_used_amount_usdt';
}

/// Loads/saves [RiskConfig] and checks a proposed order against it before
/// [TradingEngine] is allowed to send anything to Binance. This is
/// deliberately separate from order *validation* (quantity/price
/// rounding against exchange filters) — this class enforces the user's
/// own risk limits, not Binance's.
class RiskManager {
  RiskManager(this._settings);
  final SettingsRepository _settings;

  Future<RiskConfig> getConfig() async {
    return RiskConfig(
      maxTradeAmountUsdt: await _getDouble(RiskKeys.maxTradeAmount, 100),
      maxPositionSizeUsdt: await _getDouble(RiskKeys.maxPositionSize, 500),
      maxOpenOrders: await _settings.getInt(RiskKeys.maxOpenOrders, fallback: 5),
      maxDailyRiskUsdt: await _getDouble(RiskKeys.maxDailyRisk, 50),
      defaultStopLossPct: await _getDouble(RiskKeys.defaultStopLossPct, 2.0),
      defaultTakeProfitPct: await _getDouble(RiskKeys.defaultTakeProfitPct, 4.0),
      emergencyStopActive: await _settings.getBool(RiskKeys.emergencyStop),
    );
  }

  Future<void> saveConfig(RiskConfig config) async {
    await _setDouble(RiskKeys.maxTradeAmount, config.maxTradeAmountUsdt);
    await _setDouble(RiskKeys.maxPositionSize, config.maxPositionSizeUsdt);
    await _settings.setInt(RiskKeys.maxOpenOrders, config.maxOpenOrders);
    await _setDouble(RiskKeys.maxDailyRisk, config.maxDailyRiskUsdt);
    await _setDouble(RiskKeys.defaultStopLossPct, config.defaultStopLossPct);
    await _setDouble(RiskKeys.defaultTakeProfitPct, config.defaultTakeProfitPct);
    await _settings.setBool(RiskKeys.emergencyStop, config.emergencyStopActive);
  }

  Future<void> setEmergencyStop(bool active) async {
    await _settings.setBool(RiskKeys.emergencyStop, active);
  }

  /// Checks a proposed order's USDT notional and the account's current
  /// open-order count against the configured limits. Returns null when
  /// the order is within limits, or a [RiskCheckFailure] explaining which
  /// limit blocked it.
  Future<RiskCheckFailure?> checkOrder({
    required double orderNotionalUsdt,
    required double currentPositionNotionalUsdt,
    required int currentOpenOrders,
  }) async {
    final config = await getConfig();

    if (config.emergencyStopActive) {
      return const RiskCheckFailure('Emergency Stop is active — new orders are blocked.');
    }
    if (orderNotionalUsdt > config.maxTradeAmountUsdt) {
      return RiskCheckFailure(
        'Order size (${orderNotionalUsdt.toStringAsFixed(2)} USDT) exceeds your Max Trade Amount '
        '(${config.maxTradeAmountUsdt.toStringAsFixed(2)} USDT).',
      );
    }
    if (currentPositionNotionalUsdt + orderNotionalUsdt > config.maxPositionSizeUsdt) {
      return RiskCheckFailure(
        'This order would exceed your Max Position Size '
        '(${config.maxPositionSizeUsdt.toStringAsFixed(2)} USDT) for this symbol.',
      );
    }
    if (currentOpenOrders >= config.maxOpenOrders) {
      return RiskCheckFailure('You already have the maximum of ${config.maxOpenOrders} open orders.');
    }

    final dailyUsed = await _todaysUsedRisk();
    if (dailyUsed + orderNotionalUsdt > config.maxDailyRiskUsdt) {
      return RiskCheckFailure(
        'This order would exceed your Max Daily Risk (${config.maxDailyRiskUsdt.toStringAsFixed(2)} USDT).',
      );
    }

    return null;
  }

  /// Call after a BUY order is successfully placed so the daily-risk
  /// counter reflects capital actually committed today.
  Future<void> recordUsedRisk(double orderNotionalUsdt) async {
    final today = _todayKey();
    final storedDate = await _settings.getString(RiskKeys.dailyRiskUsedDate);
    final priorAmount = storedDate == today ? await _getDouble(RiskKeys.dailyRiskUsedAmount, 0) : 0.0;
    await _settings.setString(RiskKeys.dailyRiskUsedDate, today);
    await _setDouble(RiskKeys.dailyRiskUsedAmount, priorAmount + orderNotionalUsdt);
  }

  Future<double> _todaysUsedRisk() async {
    final today = _todayKey();
    final storedDate = await _settings.getString(RiskKeys.dailyRiskUsedDate);
    if (storedDate != today) return 0;
    return _getDouble(RiskKeys.dailyRiskUsedAmount, 0);
  }

  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<double> _getDouble(String key, double fallback) async {
    final raw = await _settings.getString(key);
    return double.tryParse(raw ?? '') ?? fallback;
  }

  Future<void> _setDouble(String key, double value) => _settings.setString(key, '$value');
}
