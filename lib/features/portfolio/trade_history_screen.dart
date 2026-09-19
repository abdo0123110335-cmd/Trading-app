import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';

final _tradesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(tradeRepositoryProvider).getTrades();
});

class TradeHistoryScreen extends ConsumerWidget {
  const TradeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(_tradesProvider);
    final dateFmt = DateFormat('MMM d, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Trade History')),
      body: tradesAsync.when(
        data: (trades) {
          if (trades.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No trades yet. Trades placed through Live Spot Trading, or synced '
                  'from your connected Binance account, appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final totalPnl = trades.fold<double>(0, (sum, t) => sum + (t.pnl ?? 0));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total PNL', style: TextStyle(color: MarketColors.neutral)),
                    Text(
                      '${totalPnl >= 0 ? '+' : ''}${totalPnl.toStringAsFixed(2)} USDT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: totalPnl >= 0 ? MarketColors.bullish : MarketColors.bearish,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: trades.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = trades[i];
                    final isBuy = t.side == 'BUY';
                    return ListTile(
                      title: Row(
                        children: [
                          Text(t.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                            t.side,
                            style: TextStyle(
                              color: isBuy ? MarketColors.bullish : MarketColors.bearish,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Qty ${t.quantity} \u00b7 Entry ${t.entryPrice}'
                        '${t.exitPrice != null ? ' \u2192 Exit ${t.exitPrice}' : ''}'
                        '\nFee ${t.fee} ${t.feeAsset} \u00b7 ${dateFmt.format(t.openedAt)}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t.status,
                            style: const TextStyle(fontSize: 11, color: MarketColors.neutral),
                          ),
                          if (t.pnl != null)
                            Text(
                              '${t.pnl! >= 0 ? '+' : ''}${t.pnl!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: t.pnl! >= 0 ? MarketColors.bullish : MarketColors.bearish,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}
