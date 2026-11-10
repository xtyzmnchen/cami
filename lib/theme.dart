import 'package:flutter/material.dart';

/// Soft pastel pink matching the rose photo: bubblegum petals, light magenta folds.
class CamiColors {
  static const paper = Color(0xFFFFF0F5);
  static const ink = Color(0xFF5A3040);
  static const muted = Color(0xFFB07888);
  static const rose = Color(0xFFFF8FB5);
  static const roseDeep = Color(0xFFFF6B9A);
  static const blush = Color(0xFFFFE4EF);
  static const line = Color(0xFFFFCADA);
  static const glass = Color(0xF2FFFFFF);
  static const green = Color(0xFF3CB371);
  static const greenBg = Color(0xFFE8F8EF);
  static const amber = Color(0xFFE0A040);
  static const amberBg = Color(0xFFFFF6E0);
  static const red = Color(0xFFE07070);
  static const redBg = Color(0xFFFFEDED);
  static const gold = Color(0xFFFFD56A);
  static const night = Color(0xFF6A3050);
}

class CamiAssets {
  static const roseBg = 'assets/images/rose_bg.jpg';
  static const roseFlower = 'assets/images/rose_flower.png';
  static const rosePale = 'assets/images/rose_pale.png';
  static const roseBadge = 'assets/images/rose_badge.png';
  static const roseHero = 'assets/images/rose.png';
  static const crownBadge = 'assets/images/crown_badge.png';
  static const appIcon = 'assets/icon/app_icon.png';
  static const tabToday = 'assets/images/tab_today.jpg';
  static const tabCalendar = 'assets/images/tab_calendar.jpg';
  static const tabPoints = 'assets/images/tab_points.jpg';
  static const tabSummary = 'assets/images/tab_summary.jpg';
}

ThemeData camiTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: CamiColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CamiColors.rose,
      primary: CamiColors.roseDeep,
      surface: CamiColors.paper,
      brightness: Brightness.light,
    ),
    cardTheme: CardThemeData(
      color: CamiColors.glass,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x55FFFFFF)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CamiColors.roseDeep,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      indicatorColor: CamiColors.blush,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? CamiColors.roseDeep : CamiColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? CamiColors.roseDeep : CamiColors.muted);
      }),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CamiColors.paper,
      foregroundColor: CamiColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: CamiColors.ink,
      displayColor: CamiColors.ink,
    ),
  );
}
