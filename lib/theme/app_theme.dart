import 'package:flutter/material.dart';

/// Sistema de diseño FitPulse.
/// Los mismos valores viven en la web (src/styles.scss) para que ambas
/// aplicaciones se vean como hermanas.
class FP {
  FP._();

  // Marca
  static const red = Color(0xFFE8433A);
  static const redDark = Color(0xFFC9322A);
  static const redSoft = Color(0xFFFDECEA);

  // Texto
  static const ink = Color(0xFF14221E);
  static const muted = Color(0xFF5A6B66);
  static const subtle = Color(0xFF8A9A95);

  // Superficies
  static const bg = Color(0xFFFFFFFF);
  static const card = Color(0xFFEDF2F0);
  static const track = Color(0xFFD5DEDA);
  static const border = Color(0xFFDDE3E1);
  static const mint = Color(0xFFCFE8DB);
  static const mintSoft = Color(0xFFE5F3EB);

  // Estados / categorías
  static const green = Color(0xFF2E9E6B);
  static const amber = Color(0xFFF2A33A);
  static const indigo = Color(0xFF5B6CE8);
  static const blue = Color(0xFF2F8FD6);

  static const radius = 16.0;
}

/// Estilos de texto compartidos.
class T {
  T._();
  static const display = TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: FP.ink, letterSpacing: -0.8, height: 1.05);
  static const h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: FP.ink, letterSpacing: -0.5);
  static const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: FP.ink, letterSpacing: -0.3);
  static const h3 = TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: FP.ink);
  static const body = TextStyle(fontSize: 15, color: FP.ink, height: 1.35);
  static const bodyStrong = TextStyle(fontSize: 15, color: FP.ink, fontWeight: FontWeight.w700);
  static const muted = TextStyle(fontSize: 14, color: FP.muted, height: 1.35);
  static const small = TextStyle(fontSize: 12.5, color: FP.muted, height: 1.3);
  static const label = TextStyle(fontSize: 12, color: FP.muted, fontWeight: FontWeight.w600, letterSpacing: 0.3);
}

ThemeData buildFitPulseTheme() {
  final r = BorderRadius.circular(14);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FP.red,
      primary: FP.red,
      secondary: FP.green,
      surface: FP.bg,
    ),
    scaffoldBackgroundColor: FP.bg,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: FP.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: FP.ink,
      centerTitle: false,
      titleTextStyle: TextStyle(color: FP.ink, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FP.bg,
      hintStyle: const TextStyle(color: FP.subtle),
      labelStyle: const TextStyle(color: FP.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: FP.border)),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: FP.border)),
      focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: FP.red, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: FP.redDark)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: FP.redDark, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: FP.red,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: FP.ink,
        side: const BorderSide(color: FP.border),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: FP.ink, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FP.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FP.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FP.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? FP.green : FP.track),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: FP.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: FP.redSoft,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? FP.red : FP.subtle,
            size: 24,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? FP.red : FP.muted,
          )),
    ),
    dividerTheme: const DividerThemeData(color: FP.border, thickness: 1, space: 1),
  );
}
