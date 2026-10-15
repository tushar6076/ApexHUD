// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:lottie/lottie.dart';
import '../core/constants.dart';
import '../services/audio/sfx_player.dart';
import 'hud_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Dismiss native white splash once the Flutter widget tree is active
    FlutterNativeSplash.remove();
    _startBootSequence();
  }

  Future<void> _startBootSequence() async {
    SfxPlayer().initialize();

    // Lottie animation duration
    await Future.delayed(const Duration(milliseconds: 2400));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => const HudScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Lottie.asset(
                AppConstants.lottieLoading,
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "APEX_ROVER // SYSTEM BOOT",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 14,
                letterSpacing: 2.2,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "INITIALIZING TELEMETRY & CONTROLS",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 10,
                letterSpacing: 1.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}