import 'package:flutter/material.dart';
import 'screens.dart';

const kPrimary = Color(0xFFE8433A);
const kCard = Color(0xFFE8EEEC);
const kMint = Color(0xFFCFE8DB);
const kGreen = Color(0xFF2E9E6B);
const kText = Color(0xFF14221E);
const kMuted = Color(0xFF5A6B66);
const kBorder = Color(0xFFDDE3E1);

void main() => runApp(const FitPulseApp());

class FitPulseApp extends StatelessWidget {
  const FitPulseApp({super.key});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(14);
    return MaterialApp(
      title: 'FitPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0, foregroundColor: kText,
            titleTextStyle: TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.w800)),
        inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: Colors.white,
            hintStyle: const TextStyle(color: kMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: kBorder))),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52), backgroundColor: kPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                shape: RoundedRectangleBorder(borderRadius: r))),
        navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white, indicatorColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                fontSize: 12, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
                color: s.contains(WidgetState.selected) ? kPrimary : kMuted))),
      ),
      home: const AuthScreen(),
    );
  }
}
