// lib/screens/hud_screen.dart
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/audio/sfx_player.dart';
import '../services/udp/udp_connector.dart';
import '../styles/color.dart';
import '../widgets/control_pad.dart';
import '../widgets/telemetry_dashboard.dart';
import '../widgets/utility_bar.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  final UdpConnector _udpConnector = UdpConnector();
  final SfxPlayer _sfxPlayer = SfxPlayer();

  @override
  void initState() {
    super.initState();
    _sfxPlayer.initialize();
    _sfxPlayer.startEngineBoot();
    _udpConnector.connect();
  }

  @override
  void dispose() {
    _sfxPlayer.stopAll();
    _udpConnector.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Cyberpunk Image
          Image.asset(
            AppConstants.imgHudBackground,
            fit: BoxFit.cover,
            color: AppColors.darkBackground.withValues(alpha: 0.82),
            colorBlendMode: BlendMode.darken,
          ),

          // Cyberpunk Vignette Overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  AppColors.darkBackground.withValues(alpha: 0.65),
                  AppColors.darkBackground.withValues(alpha: 0.95),
                ],
                stops: const [0.35, 0.75, 1.0],
              ),
            ),
          ),

          // Foreground HUD Layer
          const SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: UtilityBar(),
                ),
                Center(
                  child: TelemetryDashboard(),
                ),
                Positioned.fill(
                  child: ControlPad(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}