import 'package:flutter/material.dart';

import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/services/trading_engine/trading_engine.dart';

/// Shows the mandatory pre-order confirmation. No order in this app is
/// ever placed without this dialog returning `true` — TradingEngine
/// itself doesn't call this (it's a UI concern), but every screen that
/// calls TradingEngine.placeOrder MUST show this first.
Future<bool> showOrderConfirmationDialog(
  BuildContext context, {
  required String symbol,
  required OrderSide side,
  required OrderType type,
  required double quantity,
  double? price,
  required double estimatedTotal,
  required double estimatedFee,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: MarketColors.surfaceDarkElevated,
      title: Text('Confirm ${side == OrderSide.buy ? 'BUY' : 'SELL'} Order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('Symbol', symbol),
          _row(
            'Side',
            side == OrderSide.buy ? 'BUY' : 'SELL',
            valueColor: side == OrderSide.buy ? MarketColors.bullish : MarketColors.bearish,
          ),
          _row('Order Type', type == OrderType.market ? 'Market' : 'Limit'),
          _row('Quantity', '$quantity'),
          if (price != null) _row('Price', '$price'),
          const Divider(height: 24),
          _row('Estimated Total', '${estimatedTotal.toStringAsFixed(2)} USDT'),
          _row('Estimated Fee', '${estimatedFee.toStringAsFixed(4)} USDT'),
          const SizedBox(height: 12),
          const Text(
            'This places a REAL order on your Binance Spot account.',
            style: TextStyle(fontSize: 11, color: MarketColors.neutral),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: side == OrderSide.buy ? MarketColors.bullish : MarketColors.bearish,
          ),
          child: const Text('CONFIRM ORDER'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Widget _row(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: MarketColors.neutral)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
      ],
    ),
  );
}
