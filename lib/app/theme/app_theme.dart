import 'package:flutter/material.dart';

import 'app_palette.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.coral,
      brightness: Brightness.light,
      primary: AppPalette.coral,
      secondary: AppPalette.sky,
      surface: AppPalette.white,
    );

    final baseTextTheme = Typography.material2021().black.apply(
      bodyColor: AppPalette.ink,
      displayColor: AppPalette.ink,
    );

    final textTheme = baseTextTheme.copyWith(
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.3),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: AppPalette.slate,
        height: 1.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.cream,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.white.withValues(alpha: 0.86),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: AppPalette.white.withValues(alpha: 0.82),
        indicatorColor: AppPalette.blush,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: isSelected ? AppPalette.ink : AppPalette.slate,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
    );
  }
}
