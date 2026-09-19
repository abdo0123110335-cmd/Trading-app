import 'package:flutter/material.dart';

/// Trading-app color semantics used across charts, tickers, and signal
/// badges. Kept separate from [ColorScheme] because "bullish green" /
/// "bearish red" are domain colors, not Material roles.
class MarketColors {
  const MarketColors._();

  static const Color bullish = Color(0xFF26A69A); // teal-green, Binance-like
  static const Color bearish = Color(0xFFEF5350); // red
  static const Color neutral = Color(0xFF9598A1);
  static const Color warning = Color(0xFFFFA726);

  static const Color surfaceDark = Color(0xFF0E1117);
  static const Color surfaceDarkElevated = Color(0xFF161A23);
  static const Color borderDark = Color(0xFF232733);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const seed = Color(0xFF2962FF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: MarketColors.surfaceDark,
      primary: seed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MarketColors.surfaceDark,
      canvasColor: MarketColors.surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: MarketColors.surfaceDark,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: MarketColors.surfaceDarkElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MarketColors.borderDark),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MarketColors.surfaceDarkElevated,
        indicatorColor: seed.withValues(alpha: 0.18),
        elevation: 0,
        height: 64,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: MarketColors.surfaceDarkElevated,
      ),
      dividerTheme: const DividerThemeData(
        color: MarketColors.borderDark,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MarketColors.neutral,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MarketColors.surfaceDarkElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: MarketColors.borderDark),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: MarketColors.surfaceDarkElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
