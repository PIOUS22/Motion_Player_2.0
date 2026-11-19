import 'package:flutter/material.dart';
const bg = Color(0xFF121212), cyan = Color(0xFF00E5FF), orange = Color(0xFFFF9100), card = Color(0xFF1E1E1E);
final darkTheme = ThemeData(
  useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: bg,
  colorScheme: const ColorScheme.dark(primary: cyan, secondary: orange, surface: card),
  appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0),
  navigationBarTheme: NavigationBarThemeData(backgroundColor: const Color(0xFF181818), indicatorColor: cyan.withOpacity(.2)),
);
