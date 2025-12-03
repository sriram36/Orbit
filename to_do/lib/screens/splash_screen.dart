import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;

  const SplashScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to home screen after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(
              onThemeChanged: widget.onThemeChanged,
              currentTheme: widget.currentTheme,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Icon
            ClipOval(
              child: Image.asset(
                'assets/icon/icon.jpg',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            )
                .animate()
                .scale(
                    duration: 1000.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0, 0),
                    end: const Offset(1, 1))
                .fadeIn(duration: 600.ms)
                .shimmer(delay: 1000.ms, duration: 1000.ms),
            const SizedBox(height: 24),
            // App Name
            Text(
              'Orbit',
              style: GoogleFonts.outfit(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00FFFF),
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 600.ms).slideY(
                begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),
            const SizedBox(height: 8),
            // Tagline
            Text(
              'Stay on track, every day',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: const Color(0xFF00FFFF), // Cyan text
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
