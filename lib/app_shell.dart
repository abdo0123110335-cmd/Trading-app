import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/features/ai/ai_analysis_screen.dart';
import 'package:binance_spot_pro/features/alerts/alerts_screen.dart';
import 'package:binance_spot_pro/features/chart/chart_screen.dart';
import 'package:binance_spot_pro/features/home/home_screen.dart';
import 'package:binance_spot_pro/features/markets/markets_screen.dart';
import 'package:binance_spot_pro/features/portfolio/portfolio_screen.dart';
import 'package:binance_spot_pro/features/portfolio/trade_history_screen.dart';
import 'package:binance_spot_pro/features/screener/screener_screen.dart';
import 'package:binance_spot_pro/features/settings/settings_screen.dart';
import 'package:binance_spot_pro/features/signals/signals_screen.dart';
import 'package:binance_spot_pro/features/trading/risk_management_screen.dart';
import 'package:binance_spot_pro/features/trading/trade_calculator_screen.dart';
import 'package:binance_spot_pro/features/watchlists/watchlists_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final _tabs = <Widget>[
    HomeScreen(onMenuPressed: () => _scaffoldKey.currentState?.openDrawer()),
    MarketsScreen(onMenuPressed: () => _scaffoldKey.currentState?.openDrawer()),
    ChartScreen(onMenuPressed: () => _scaffoldKey.currentState?.openDrawer()),
    ScreenerScreen(onMenuPressed: () => _scaffoldKey.currentState?.openDrawer()),
    SignalsScreen(onMenuPressed: () => _scaffoldKey.currentState?.openDrawer()),
  ];

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityStatusProvider).asData?.value ?? true;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const _AppDrawer(),
      body: Column(
        children: [
          if (!isOnline) const _OfflineBanner(),
          Expanded(child: _tabs[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Markets'),
          NavigationDestination(icon: Icon(Icons.candlestick_chart_outlined), selectedIcon: Icon(Icons.candlestick_chart), label: 'Chart'),
          NavigationDestination(icon: Icon(Icons.filter_alt_outlined), selectedIcon: Icon(Icons.filter_alt), label: 'Screener'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Signals'),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: MarketColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 14, color: MarketColors.warning),
          SizedBox(width: 6),
          Text(
            'OFFLINE — showing last known data',
            style: TextStyle(fontSize: 11, color: MarketColors.warning, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Binance Spot Pro',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('On-device Spot analysis & trading'),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Watchlists'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const WatchlistsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Alerts'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AlertsScreen()));
              },
            ),
            _navItem(context, Icons.account_balance_wallet_outlined, 'Portfolio', const PortfolioScreen()),
            _navItem(context, Icons.history, 'Trade History', const TradeHistoryScreen()),
            _navItem(context, Icons.calculate_outlined, 'Entry/SL/TP Calculator', const TradeCalculatorScreen()),
            _navItem(context, Icons.shield_outlined, 'Risk Management', const RiskManagementScreen()),
            _navItem(context, Icons.auto_awesome_outlined, 'AI Analysis', const AiAnalysisScreen()),
            const Divider(),
            _navItem(context, Icons.settings_outlined, 'Settings', const SettingsScreen()),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, Widget screen) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}
