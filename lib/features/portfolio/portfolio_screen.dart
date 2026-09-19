import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/features/trading/binance_connection_screen.dart';
import 'package:binance_spot_pro/features/portfolio/trade_history_screen.dart';

final _hasCredentialsProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(secureCredentialsStoreProvider).hasCredentials();
});

final _liveAccountProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(binanceRestClientProvider);
  final result = await client.getAccount();
  return result.when(ok: (data) => data, err: (e) => throw e);
});

final _manualHoldingsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(portfolioRepositoryProvider).getHoldings();
});

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCredentialsAsync = ref.watch(_hasCredentialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Trade History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TradeHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Binance Connection',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BinanceConnectionScreen()))
                .then((_) => ref.invalidate(_hasCredentialsProvider)),
          ),
        ],
      ),
      body: hasCredentialsAsync.when(
        data: (connected) => connected ? const _LivePortfolio() : const _ManualPortfolio(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}

class _LivePortfolio extends ConsumerWidget {
  const _LivePortfolio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(_liveAccountProvider);

    return accountAsync.when(
      data: (account) {
        final balances = (account['balances'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .where((b) {
              final free = double.tryParse('${b['free']}') ?? 0;
              final locked = double.tryParse('${b['locked']}') ?? 0;
              return free + locked > 0;
            })
            .toList();

        double totalFree = 0, totalLocked = 0;
        for (final b in balances) {
          totalFree += double.tryParse('${b['free']}') ?? 0;
          totalLocked += double.tryParse('${b['locked']}') ?? 0;
        }
        final fmt = NumberFormat('#,##0.########');

        return RefreshIndicator(
          onRefresh: () => ref.refresh(_liveAccountProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Balance (all assets)', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '${fmt.format(totalFree + totalLocked)} units',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _statTile('Available', fmt.format(totalFree))),
                          Expanded(child: _statTile('Locked', fmt.format(totalLocked))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Assets', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final b in balances) ...[
                      ListTile(
                        title: Text(b['asset'] as String),
                        trailing: Text(
                          fmt.format(
                            (double.tryParse('${b['free']}') ?? 0) +
                                (double.tryParse('${b['locked']}') ?? 0),
                          ),
                        ),
                      ),
                      if (b != balances.last) const Divider(height: 1),
                    ],
                    if (balances.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No balances found on this account.'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: MarketColors.neutral)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ManualPortfolio extends ConsumerWidget {
  const _ManualPortfolio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(_manualHoldingsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addHolding(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: MarketColors.neutral, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No Binance account connected — track coins manually, or connect your '
                      'account from the icon above for live balances.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: holdingsAsync.when(
              data: (holdings) {
                if (holdings.isEmpty) {
                  return const Center(child: Text('No holdings yet. Tap + to add one.'));
                }
                return ListView.separated(
                  itemCount: holdings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final h = holdings[i];
                    return ListTile(
                      title: Text(h.asset),
                      subtitle: Text('Avg buy: ${h.avgBuyPrice}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${h.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              await ref.read(portfolioRepositoryProvider).deleteHolding(h.asset);
                              ref.invalidate(_manualHoldingsProvider);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addHolding(BuildContext context, WidgetRef ref) async {
    final assetController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('Add holding'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: assetController, decoration: const InputDecoration(labelText: 'Asset (e.g. BTC)')),
            TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Avg buy price (optional)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (result == true) {
      final asset = assetController.text.trim().toUpperCase();
      final qty = double.tryParse(qtyController.text) ?? 0;
      final price = double.tryParse(priceController.text) ?? 0;
      if (asset.isNotEmpty && qty > 0) {
        await ref.read(portfolioRepositoryProvider).upsertHolding(
          asset: asset,
          quantity: qty,
          avgBuyPrice: price,
        );
        ref.invalidate(_manualHoldingsProvider);
      }
    }
  }
}
