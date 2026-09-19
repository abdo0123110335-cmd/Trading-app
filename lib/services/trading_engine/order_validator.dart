import 'package:binance_spot_pro/core/api/api_exceptions.dart';
import 'package:binance_spot_pro/data/repositories/symbol_repository.dart';

class ValidatedOrder {
  const ValidatedOrder({required this.quantity, required this.price});
  final double quantity;
  final double? price;
}

/// Rounds [rawQuantity] down to the symbol's `stepSize` and [rawPrice] to
/// its `tickSize` (Binance rejects orders that don't align to these),
/// then checks both against `minQty`/`maxQty`/`minNotional`. Throws a
/// typed [AppException] the UI can show directly — never lets a
/// malformed order reach `BinanceRestClient.placeOrder` in the first
/// place.
ValidatedOrder validateOrder({
  required SymbolFilters filters,
  required double rawQuantity,
  double? rawPrice,
}) {
  final quantity = _roundToStep(rawQuantity, filters.stepSize);
  final price = rawPrice == null ? null : _roundToStep(rawPrice, filters.tickSize);

  if (filters.minQty > 0 && quantity < filters.minQty) {
    throw InvalidQuantityException(
      'Quantity must be at least ${filters.minQty} ${filters.symbol.replaceAll('USDT', '')}.',
    );
  }
  if (filters.maxQty > 0 && quantity > filters.maxQty) {
    throw InvalidQuantityException('Quantity exceeds the maximum allowed for ${filters.symbol}.');
  }
  if (quantity <= 0) {
    throw const InvalidQuantityException('Quantity must be greater than zero.');
  }

  if (price != null) {
    if (price <= 0) {
      throw const InvalidPriceException('Price must be greater than zero.');
    }
    final notional = quantity * price;
    if (filters.minNotional > 0 && notional < filters.minNotional) {
      throw InvalidQuantityException('Order total must be at least ${filters.minNotional} USDT.');
    }
  }

  return ValidatedOrder(quantity: quantity, price: price);
}

double _roundToStep(double value, double step) {
  if (step <= 0) return value;
  final steps = (value / step).floor();
  final rounded = steps * step;
  final decimals = _decimalPlaces(step);
  return double.parse(rounded.toStringAsFixed(decimals));
}

int _decimalPlaces(double step) {
  if (step <= 0) return 8;
  var decimals = 0;
  var v = step;
  while (v < 1 && decimals < 12) {
    v *= 10;
    decimals++;
  }
  return decimals;
}
