import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/data/models/ticker_24hr.dart';
import 'package:binance_spot_pro/features/chart/chart_screen.dart';

enum _SortBy { change, volume, priceAsc, priceDesc }

final _allTickersProvider = FutureProvider.autoDispose<List<Ticker24hr>>((
  ref,
) async {
  final repo = ref.watch(marketRepositoryProvider);
  final symbolsResult = await repo.getTradableUsdtSymbols();
  final tickersResult = await repo.getTickers24hr();

  final tradableSymbols = symbolsResult.when(
    ok: (rows) => rows.map((r) => r['symbol'] as String).toSet(),
    err: (e) => throw e,
  );

  return tickersResult.when(
    ok: (all) => all.where((t) => tradableSymbols.contains(t.symbol)).toList(),
    err: (e) => throw e,
  );
});

/// The Favorites watchlist's symbols, watched here so the star icon and
/// the "Favorites only" filter both reflect the same source of truth as
/// the Watchlists screen and the Screener's "Favorites" scan source.
final _favoritesProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  final id = await repo.getOrCreateFavoritesId();
  final symbols = await repo.getSymbols(id);
  return symbols.toSet();
});

final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final _sortByProvider = StateProvider.autoDispose<_SortBy>((ref) => _SortBy.volume);
final _favoritesOnlyProvider = StateProvider.autoDispose<bool>((ref) => false);

class MarketsScreen extends ConsumerWidget {
  const MarketsScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickersAsync = ref.watch(_allTickersProvider);
    final query = ref.watch(_searchQueryProvider);
    final sortBy = ref.watch(_sortByProvider);
    final favoritesOnly = ref.watch(_favoritesOnlyProvider);
    final favoritesAsync = ref.watch(_favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Markets'),
        leading: onMenuPressed == null
            ? null
            : IconButton(icon: const Icon(Icons.menu), onPressed: onMenuPressed),
        actions: [
          IconButton(
            icon: Icon(favoritesOnly ? Icons.star : Icons.star_border),
            tooltip: 'Favorites only',
            onPressed: () =>
                ref.read(_favoritesOnlyProvider.notifier).state = !favoritesOnly,
          ),
          PopupMenuButton<_SortBy>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => ref.read(_sortByProvider.notifier).state = v,
            itemBuilder: (context) => const [
              PopupMenuItem(value: _SortBy.volume, child: Text('Sort by Volume')),
              PopupMenuItem(value: _SortBy.change, child: Text('Sort by 24h Change')),
              PopupMenuItem(value: _SortBy.priceDesc, child: Text('Sort by Price (high→low)')),
              PopupMenuItem(value: _SortBy.priceAsc, child: Text('Sort by Price (low→high)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search BTC, Bitcoin, BTCUSDT…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: tickersAsync.when(
              data: (tickers) {
                final favorites = favoritesAsync.asData?.value ?? const <String>{};
                var filtered = _filterAndSort(tickers, query, sortBy);
                if (favoritesOnly) {
                  filtered = filtered.where((t) => favorites.contains(t.symbol)).toList();
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(favoritesOnly ? 'No favorites yet.' : 'No matching Spot pairs.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(_allTickersProvider.future),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _MarketRow(
                      ticker: filtered[i],
                      isFavorite: favorites.contains(filtered[i].symbol),
                      onToggleFavorite: () => _toggleFavorite(ref, filtered[i].symbol, favorites),
                    ),
                  ),
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

  List<Ticker24hr> _filterAndSort(
    List<Ticker24hr> tickers,
    String query,
    _SortBy sortBy,
  ) {
    final q = query.trim().toUpperCase();
    var filtered = tickers.where((t) {
      if (q.isEmpty) return true;
      return t.symbol.toUpperCase().contains(q) ||
          t.symbol.toUpperCase().replaceAll('USDT', '').contains(q);
    }).toList();

    switch (sortBy) {
      case _SortBy.volume:
        filtered.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
      case _SortBy.change:
        filtered.sort((a, b) => b.priceChangePercent.compareTo(a.priceChangePercent));
      case _SortBy.priceDesc:
        filtered.sort((a, b) => b.lastPrice.compareTo(a.lastPrice));
      case _SortBy.priceAsc:
        filtered.sort((a, b) => a.lastPrice.compareTo(b.lastPrice));
    }
    return filtered;
  }

  Future<void> _toggleFavorite(WidgetRef ref, String symbol, Set<String> current) async {
    final repo = ref.read(watchlistRepositoryProvider);
    final id = await repo.getOrCreateFavoritesId();
    if (current.contains(symbol)) {
      await repo.removeSymbol(id, symbol);
    } else {
      await repo.addSymbol(id, symbol);
    }
    ref.invalidate(_favoritesProvider);
  }
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.ticker,
    required this.isFavorite,
    required this.onToggleFavorite,
  });
  final Ticker24hr ticker;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat('#,##0.00########');
    final volFmt = NumberFormat.compact();

    return ListTile(
      leading: IconButton(
        icon: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          color: isFavorite ? MarketColors.warning : MarketColors.neutral,
          size: 20,
        ),
        onPressed: onToggleFavorite,
        tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
      ),
      title: Text(ticker.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Vol ${volFmt.format(ticker.quoteVolume)} USDT'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(priceFmt.format(ticker.lastPrice)),
          Text(
            '${ticker.isBullish ? '+' : ''}${ticker.priceChangePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              color: ticker.isBullish ? MarketColors.bullish : MarketColors.bearish,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChartScreen(symbol: ticker.symbol)),
        );
      },
    );
  }
}
