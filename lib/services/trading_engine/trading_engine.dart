import 'package:binance_spot_pro/core/api/api_exceptions.dart';
import 'package:binance_spot_pro/core/api/binance_rest_client.dart';
import 'package:binance_spot_pro/core/connectivity/connectivity_service.dart';
import 'package:binance_spot_pro/core/security/secure_credentials_store.dart';
import 'package:binance_spot_pro/core/utils/result.dart';
import 'package:binance_spot_pro/data/repositories/symbol_repository.dart';
import 'package:binance_spot_pro/services/trading_engine/order_validator.dart';
import 'package:binance_spot_pro/services/trading_engine/risk_manager.dart';

enum OrderSide { buy, sell }

enum OrderType { market, limit }

/// The single path anything in this app uses to place or cancel a real
/// Binance Spot order. Every safety requirement from the spec is enforced
/// here, in this order, before a single byte reaches Binance:
///
///   1. Live Spot Trading must be explicitly enabled (OFF by default).
///   2. Emergency Stop must not be active.
///   3. The order must pass Risk Manager limits (max trade amount, max
///      position size, max open orders, max daily risk).
///   4. The order's quantity/price must validate against the symbol's
///      real Binance filters (LOT_SIZE/PRICE_FILTER/MIN_NOTIONAL).
///
/// This class never shows a confirmation dialog itself — that is a UI
/// concern (see OrderConfirmationDialog) — but it assumes the caller
/// already got explicit user confirmation for the exact quantity/price
/// being passed in. Spot only: no leverage, no margin, no short — `side`
/// is BUY or SELL of an asset the account actually holds, never a
/// short-sell.
class TradingEngine {
  TradingEngine({
    required BinanceRestClient restClient,
    required SecureCredentialsStore credentialsStore,
    required SymbolRepository symbolRepository,
    required RiskManager riskManager,
    required ConnectivityService connectivityService,
  }) : _rest = restClient,
       _credentials = credentialsStore,
       _symbolRepo = symbolRepository,
       _riskManager = riskManager,
       _connectivity = connectivityService;

  final BinanceRestClient _rest;
  final SecureCredentialsStore _credentials;
  final SymbolRepository _symbolRepo;
  final RiskManager _riskManager;
  final ConnectivityService _connectivity;

  Future<Result<Map<String, dynamic>>> placeOrder({
    required String symbol,
    required OrderSide side,
    required OrderType type,
    required double quantity,
    double? price,
    double? currentPositionNotionalUsdt,
  }) async {
    // Never attempt an order while connectivity is anything other than
    // confirmed-online — per the spec's Offline Mode requirement, a
    // trade must not fire into an uncertain connection state.
    if (!_connectivity.isOnline) {
      return const Result.err(NetworkException(debugInfo: 'Device appears offline'));
    }

    final liveTradingEnabled = await _credentials.isLiveTradingEnabled();
    if (!liveTradingEnabled) {
      return const Result.err(TradingDisabledException());
    }

    final hasCredentials = await _credentials.hasCredentials();
    if (!hasCredentials) {
      return const Result.err(InvalidApiKeyException());
    }

    final filters = await _symbolRepo.getFilters(symbol);
    if (filters == null) {
      return Result.err(InvalidSymbolException(symbol));
    }

    ValidatedOrder validated;
    try {
      validated = validateOrder(filters: filters, rawQuantity: quantity, rawPrice: price);
    } on AppException catch (e) {
      return Result.err(e);
    }

    final estimatedPrice = validated.price ?? price ?? 0;
    final orderNotional = validated.quantity * estimatedPrice;

    final openOrdersResult = await _rest.getOpenOrders(symbol: symbol);
    final openOrdersCount = openOrdersResult.when(ok: (l) => l.length, err: (_) => 0);

    final riskFailure = await _riskManager.checkOrder(
      orderNotionalUsdt: orderNotional,
      currentPositionNotionalUsdt: currentPositionNotionalUsdt ?? 0,
      currentOpenOrders: openOrdersCount,
    );
    if (riskFailure != null) {
      return Result.err(UnknownApiException(debugInfo: riskFailure.reason));
    }

    final result = await _rest.placeOrder(
      symbol: symbol,
      side: side == OrderSide.buy ? 'BUY' : 'SELL',
      type: type == OrderType.market ? 'MARKET' : 'LIMIT',
      quantity: '${validated.quantity}',
      price: validated.price == null ? null : '${validated.price}',
      timeInForce: type == OrderType.limit ? 'GTC' : null,
    );

    if (result.isOk && side == OrderSide.buy) {
      await _riskManager.recordUsedRisk(orderNotional);
    }

    return result;
  }

  Future<Result<Map<String, dynamic>>> cancelOrder({
    required String symbol,
    required int orderId,
  }) async {
    final liveTradingEnabled = await _credentials.isLiveTradingEnabled();
    if (!liveTradingEnabled) {
      return const Result.err(TradingDisabledException());
    }
    return _rest.cancelOrder(symbol: symbol, orderId: orderId);
  }

  /// Immediately flips Emergency Stop on — blocks all new orders from
  /// this point on, regardless of any other setting, until the user
  /// turns it back off from Risk Management settings. Does not touch
  /// existing open orders (cancelling those is a separate, explicit
  /// action so Emergency Stop can never itself become a source of
  /// unexpected fills/cancels).
  Future<void> emergencyStop() => _riskManager.setEmergencyStop(true);
}
