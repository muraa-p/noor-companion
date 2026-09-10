import 'package:flutter/material.dart';

/// Soothing emerald + amber palette used throughout Noor.
///
/// The palette is intentionally warm, muted and high-contrast-safe so it feels
/// calm to read the Qur'an in both light and dark modes.
class AppColors {
  AppColors._();

  // ---- Brand / primary (deep emerald) ----
  static const Color emerald = Color(0xFF0E7C66);
  static const Color emeraldDeep = Color(0xFF075E4E);
  static const Color emeraldSoft = Color(0xFFE6F4F0);
  static const Color teal = Color(0xFF159A7F);

  // ---- Accent (muted gold) ----
  static const Color gold = Color(0xFFB8860B);
  static const Color goldLight = Color(0xFFE3C878);
  static const Color goldDark = Color(0xFF8A6A0F);
  static const Color goldSoft = Color(0xFFFBF3DC);

  // ---- Neutrals (warm sand/grey) ----
  static const Color cream = Color(0xFFFBF7EF);
  static const Color paper = Color(0xFFFFFDF6);
  static const Color ink = Color(0xFF20302B);
  static const Color inkSoft = Color(0xFF4A5A55);
  static const Color line = Color(0xFFE3E0D8);

  // ---- Dark neutrals ----
  static const Color night = Color(0xFF0F1A17);
  static const Color nightCard = Color(0xFF162420);
  static const Color nightLine = Color(0xFF243832);
  static const Color nightInk = Color(0xFFE6EFEA);

  // ---- Semantic ----
  static const Color danger = Color(0xFFB3261E);
  static const Color info = Color(0xFF2E6FB0);

  static const Color bismillah = Color(0xFF8A6A0F);
}

/// Theme-aware foreground choices so fixed brand shades stay legible in both
/// light and dark modes. In dark mode the muted golds are brightened.
class Ui {
  Ui._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Field-safe accent text colour for labels/values on neutral surfaces.
  static Color gold(BuildContext context) =>
      isDark(context) ? AppColors.goldLight : AppColors.goldDark;

  /// Colour used for Arabic dhikr / bismillah text.
  static Color bismillah(BuildContext context) =>
      isDark(context) ? AppColors.goldLight : AppColors.bismillah;

  /// Bright emerald used for Arabic-hero text on plain backgrounds.
  static Color emerald(BuildContext context) =>
      isDark(context) ? AppColors.teal : AppColors.emeraldDeep;

  /// "Soft" accent-chip background paired with on-top [gold] text. In dark
  /// mode a warm, desaturated gold used as a chip fill with [goldLight] text.
  static Color goldSoft(BuildContext context) =>
      isDark(context) ? const Color(0xFF3A2F12) : AppColors.goldSoft;
}

/// Builds the MaterialThemeData (light or dark) with the Noor palette.
ThemeData buildNoorTheme({required Brightness brightness}) {
  final bool dark = brightness == Brightness.dark;
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.emerald,
    brightness: brightness,
    primary: dark ? AppColors.teal : AppColors.emerald,
    surface: dark ? AppColors.night : AppColors.paper,
  );

  final Color background = dark ? AppColors.night : AppColors.cream;
  final Color onBackground = dark ? AppColors.nightInk : AppColors.ink;

  final ColorScheme colorScheme = scheme.copyWith(
    surface: background,
    onSurface: onBackground,
    surfaceContainer: dark ? AppColors.nightCard : AppColors.paper,
    surfaceContainerHigh: dark ? AppColors.nightCard : AppColors.paper,
    surfaceContainerHighest: dark ? AppColors.nightLine : AppColors.line,
    outline: dark ? AppColors.nightLine : AppColors.line,
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: onBackground,
          displayColor: onBackground,
        )
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: onBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onBackground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Amiri',
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: AppColors.gold),
        foregroundColor: dark ? AppColors.goldLight : AppColors.goldDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? AppColors.nightLine : AppColors.line,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.nightCard : AppColors.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark ? AppColors.nightLine : AppColors.line,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.emerald, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? AppColors.nightCard : AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? AppColors.night : background,
      indicatorColor: AppColors.emeraldSoft.withValues(alpha: dark ? 0.18 : 0.9),
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(
        dark ? AppColors.nightLine : AppColors.line,
      ),
    ),
  );
}
