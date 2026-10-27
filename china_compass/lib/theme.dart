import 'package:flutter/material.dart';

/// Modern, calm design: light canvas, white rounded surfaces, a deep navy "ink"
/// for controls, and soft per-topic colors (see widgets/icons.dart) for orientation.
const ink = Color(0xFF1B2140);
const accent = Color(0xFF8B5CF6); // neon violet: title bar, tab dot, progress rings
const fontFamily = 'PlusJakartaSans';

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final base = ColorScheme.fromSeed(
    seedColor: ink,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );
  final scheme = base.copyWith(
    primary: light ? ink : const Color(0xFFC9D0FF),
    onPrimary: light ? Colors.white : ink,
    primaryContainer: light ? const Color(0xFFE9EBF5) : const Color(0xFF2A3058),
    onPrimaryContainer: light ? ink : const Color(0xFFE3E6FF),
    tertiary: light ? const Color(0xFF2F6FED) : const Color(0xFF8DB3FF), // links
    surface: light ? const Color(0xFFF4F5F8) : const Color(0xFF0B0C10),
    onSurface: light ? const Color(0xFF15182B) : const Color(0xFFF2F3F7),
    onSurfaceVariant: light ? const Color(0xFF6B6F80) : const Color(0xFF9A9EAE),
    surfaceContainerLowest: light ? Colors.white : const Color(0xFF181A22),
    surfaceContainerLow: light ? Colors.white : const Color(0xFF181A22),
    surfaceContainer: light ? const Color(0xFFF0F1F5) : const Color(0xFF22252F),
    surfaceContainerHigh: light ? const Color(0xFFE9EAF0) : const Color(0xFF2A2D38),
    surfaceContainerHighest: light ? const Color(0xFFE2E4EB) : const Color(0xFF343744),
    outline: light ? const Color(0xFFB9BCC8) : const Color(0xFF5A5E6C),
    outlineVariant: light ? const Color(0xFFE7E8EE) : const Color(0xFF2E313C),
  );

  final base2021 = light ? Typography.material2021().black : Typography.material2021().white;
  final text = base2021
      .apply(fontFamily: fontFamily, bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
      .copyWith();
  final textTheme = text.copyWith(
    headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15),
    headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.2),
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3, fontSize: 19),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
  );

  return ThemeData(
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.8, space: 0.8),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
  );
}
