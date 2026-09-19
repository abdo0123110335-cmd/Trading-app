import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/core/api/api_exceptions.dart';
import 'package:binance_spot_pro/data/repositories/symbol_repository.dart';
import 'package:binance_spot_pro/services/trading_engine/order_validator.dart';

const _btcFilters = SymbolFilters(
  symbol: 'BTCUSDT',
  minQty: 0.00001,
  maxQty: 9000,
  stepSize: 0.00001,
  minNotional: 10,
  tickSize: 0.01,
  basePrecision: 8,
  quotePrecision: 8,
);

void main() {
  group('validateOrder', () {
    test('rounds quantity down to the step size', () {
      final result = validateOrder(filters: _btcFilters, rawQuantity: 0.123456, rawPrice: 50000);
      expect(result.quantity, closeTo(0.12345, 1e-9));
    });

    test('rounds price down to the tick size', () {
      final result = validateOrder(filters: _btcFilters, rawQuantity: 0.01, rawPrice: 50000.567);
      expect(result.price, closeTo(50000.56, 1e-9));
    });

    test('throws InvalidQuantityException when below minQty', () {
      expect(
        () => validateOrder(filters: _btcFilters, rawQuantity: 0.000001, rawPrice: 50000),
        throwsA(isA<InvalidQuantityException>()),
      );
    });

    test('throws InvalidQuantityException when above maxQty', () {
      expect(
        () => validateOrder(filters: _btcFilters, rawQuantity: 99999, rawPrice: 50000),
        throwsA(isA<InvalidQuantityException>()),
      );
    });

    test('throws InvalidQuantityException when order notional is below minNotional', () {
      expect(
        () => validateOrder(filters: _btcFilters, rawQuantity: 0.00001, rawPrice: 1),
        throwsA(isA<InvalidQuantityException>()),
      );
    });

    test('accepts a well-formed order within all limits', () {
      final result = validateOrder(filters: _btcFilters, rawQuantity: 0.001, rawPrice: 50000);
      expect(result.quantity, greaterThan(0));
      expect(result.price, greaterThan(0));
    });

    test('market orders (no price) skip the minNotional check but still validate quantity', () {
      final result = validateOrder(filters: _btcFilters, rawQuantity: 0.001);
      expect(result.price, isNull);
      expect(result.quantity, closeTo(0.001, 1e-9));
    });
  });
}
