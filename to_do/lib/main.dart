import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: SplashScreen(
        onThemeChanged: _toggleTheme,
        currentTheme: _themeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // User Palette References:
    // Primary: #00FFFF (Cyan)
    // Accents: #40E0D0 (Turquoise)
    // Rings: #48D1CC (Medium Turquoise)
    // Dark BG: #1A2132 (Dark Navy)
    // Light Core: #FFFFFF (Pure White)
    // Dark Turquoise: #00CED1

    var baseTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      // Light Mode: Soft Cyan Tint (#F5FDFD) | Dark Mode: Dark Navy (#1A2132)
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF1A2132) : const Color(0xFFF5FDFD),

      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00FFFF),
        brightness: brightness,
        // Light Mode: Dark Turquoise for contrast | Dark Mode: Neon Cyan
        primary: isDark ? const Color(0xFF00FFFF) : const Color(0xFF00CED1),
        // Secondary is Turquoise for both
        secondary: const Color(0xFF40E0D0),
        // Surface: Dark Navy vs Pure White
        surface: isDark ? const Color(0xFF1A2132) : const Color(0xFFFFFFFF),
        // Text: White vs Dark Navy
        onSurface: isDark ? Colors.white : const Color(0xFF1A2132),
        // Secondary Text: Light Grey vs Lighter Navy
        onSurfaceVariant: isDark ? Colors.white70 : const Color(0xFF252D40),
        // Container for cards in dark mode (slightly lighter navy)
        surfaceContainer: isDark ? const Color(0xFF252D40) : const Color(0xFFFFFFFF),
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: brightness == Brightness.light ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
