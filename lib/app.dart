import 'package:flutter/material.dart';

import 'package:binance_spot_pro/app_shell.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';

class BinanceSpotProApp extends StatelessWidget {
  const BinanceSpotProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Binance Spot Pro',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
