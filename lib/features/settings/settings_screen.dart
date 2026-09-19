import 'package:flutter/material.dart';

import 'package:binance_spot_pro/features/ai/ai_provider_settings_screen.dart';
import 'package:binance_spot_pro/features/settings/data_management_screen.dart';
import 'package:binance_spot_pro/features/settings/general_settings_screen.dart';
import 'package:binance_spot_pro/features/settings/security_screen.dart';
import 'package:binance_spot_pro/features/settings/strategy_settings_screen.dart';
import 'package:binance_spot_pro/features/trading/binance_connection_screen.dart';
import 'package:binance_spot_pro/features/trading/risk_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('General'),
          _item(context, Icons.tune, 'General', 'Theme, language, currency, notifications', const GeneralSettingsScreen()),
          const _SectionHeader('Trading'),
          _item(context, Icons.tune_outlined, 'Strategy Settings', 'RSI+EMA strategy, filters, score weights', const StrategySettingsScreen()),
          _item(context, Icons.shield_outlined, 'Risk Management', 'Trade/position/order limits, Emergency Stop', const RiskManagementScreen()),
          _item(context, Icons.account_balance_outlined, 'Binance API', 'Connect your account, Live Spot Trading toggle', const BinanceConnectionScreen()),
          const _SectionHeader('AI'),
          _item(context, Icons.auto_awesome_outlined, 'AI Provider', 'Configure the provider used by AI Analysis', const AiProviderSettingsScreen()),
          const _SectionHeader('Data & Security'),
          _item(context, Icons.storage_outlined, 'Data Management', 'Clear cache, delete local data, export/import', const DataManagementScreen()),
          _item(context, Icons.security_outlined, 'Security', 'How your keys and data are protected', const SecurityScreen()),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String subtitle, Widget screen) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}
