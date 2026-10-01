import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  runApp(const MetadataApp());
}

class MetadataApp extends StatelessWidget {
  const MetadataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metadata Reader',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: const HomePage(),
    );
  }

  ThemeData _theme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C63FF),
        secondary: Color(0xFF00D4FF),
        surface: Color(0xFF1A1A2E),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }
}
