// lib/widgets/utility_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../styles/color.dart';
import '../../styles/animate.dart';
import '../../services/udp/udp_connector.dart';
import '../../services/udp/command_service.dart';
import '../../services/udp/telemetry_parser.dart';
import '../../services/mic/mic_streamer.dart';
import '../../services/audio/sfx_player.dart';
import 'connection_dialog.dart';

class UtilityBar extends StatefulWidget {
  const UtilityBar({super.key});

  @override
  State<UtilityBar> createState() => _UtilityBarState();
}

class _UtilityBarState extends State<UtilityBar>
    with SingleTickerProviderStateMixin {
  final UdpConnector _connector = UdpConnector();
  final CommandService _cmd = CommandService();
  final SfxPlayer _sfxPlayer = SfxPlayer();

  bool _isConnected = false;
  bool _micActive = false;
  late bool _isMuted;
  int _battery = 100;
  int _distance = 0;

  StreamSubscription<bool>? _statusSub;
  StreamSubscription<TelemetryData>? _telemetrySub;

  late final AnimationController _micAnimController;
  late final Animation<double> _micWavePrimaryScale;
  late final Animation<double> _micWavePrimaryOpacity;
  late final Animation<double> _micWaveSecondaryScale;
  late final Animation<double> _micWaveSecondaryOpacity;
  late final Animation<double> _micAuraPulse;
  late final Animation<double> _micCoreScale;

  @override
  void initState() {
    super.initState();
    _isConnected = _connector.isConnected;
    _isMuted = _sfxPlayer.isMuted;

    _micAnimController = AnimationController(
      vsync: this,
      duration: AppAnimations.micPulseDuration,
    );

    _micWavePrimaryScale =
        AppAnimations.micWaveformScalePrimary(_micAnimController);
    _micWavePrimaryOpacity =
        AppAnimations.micWaveformOpacityPrimary(_micAnimController);
    _micWaveSecondaryScale =
        AppAnimations.micWaveformScaleSecondary(_micAnimController);
    _micWaveSecondaryOpacity =
        AppAnimations.micWaveformOpacitySecondary(_micAnimController);
    _micAuraPulse = AppAnimations.micAuraPulse(_micAnimController);
    _micCoreScale = AppAnimations.micCoreScale(_micAnimController);

    _statusSub = _connector.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isConnected = status;
        });
      }
    });

    _telemetrySub = _connector.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _battery = data.battery;
          _distance = data.distance;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _telemetrySub?.cancel();
    _micAnimController.dispose();
    super.dispose();
  }

  void _openDialog() {
    _sfxPlayer.playBlip();
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        backgroundColor: AppColors.darkBackground,
        content: ConnectionDialogContent(),
      ),
    );
  }

  void _toggleMic() async {
    _sfxPlayer.playBlip();
    final bool nextState = !_micActive;

    setState(() {
      _micActive = nextState;
      if (_micActive) {
        _micAnimController.repeat();
      } else {
        _micAnimController.stop();
        _micAnimController.reset();
      }
    });

    if (nextState) {
      _cmd.setMic(true);
      await MicStreamer().startStreaming();
    } else {
      await MicStreamer().stopStreaming();
      _cmd.setMic(false);
    }
  }

  void _toggleSpeaker() {
    final bool willMute = !_isMuted;
    _sfxPlayer.playLightToggle(!willMute);

    setState(() {
      _isMuted = _sfxPlayer.toggleMute();
    });
  }

  IconData _getBatteryIcon() {
    if (_battery > 85) return Icons.battery_full;
    if (_battery > 60) return Icons.battery_5_bar;
    if (_battery > 35) return Icons.battery_3_bar;
    if (_battery > 15) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor() {
    if (_battery > 40) return const Color(0xFF99FF33);
    if (_battery > 20) return Colors.amberAccent;
    return AppColors.alertRed;
  }

  Widget _buildMicButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_micActive) ...[
            // Secondary Outward Sonar Wave (Phase Offset)
            AnimatedBuilder(
              animation: _micAnimController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _micWaveSecondaryScale.value,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cyberpunkCyan.withValues(
                          alpha: _micWaveSecondaryOpacity.value,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyberpunkCyan.withValues(
                            alpha: _micWaveSecondaryOpacity.value * 0.5,
                          ),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Primary Outward Sonar Wave
            AnimatedBuilder(
              animation: _micAnimController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _micWavePrimaryScale.value,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cyberpunkCyan.withValues(
                          alpha: _micWavePrimaryOpacity.value,
                        ),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyberpunkCyan.withValues(
                            alpha: _micWavePrimaryOpacity.value * 0.6,
                          ),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          // Central Mic Hardware Node
          AnimatedBuilder(
            animation: _micAnimController,
            builder: (context, child) {
              final double coreScale = _micActive ? _micCoreScale.value : 1.0;
              final double auraPulse = _micActive ? _micAuraPulse.value : 0.0;

              return Transform.scale(
                scale: coreScale,
                child: GestureDetector(
                  onTap: _toggleMic,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _micActive
                          ? AppColors.cyberpunkCyan.withValues(alpha: 0.22)
                          : AppColors.darkBackground.withValues(alpha: 0.65),
                      border: Border.all(
                        color: _micActive
                            ? AppColors.cyberpunkCyan
                            : AppColors.alertRed.withValues(alpha: 0.65),
                        width: 1.6,
                      ),
                      boxShadow: _micActive
                          ? [
                              BoxShadow(
                                color: AppColors.cyberpunkCyan.withValues(
                                  alpha: auraPulse * 0.7,
                                ),
                                blurRadius: 12 + (auraPulse * 6),
                                spreadRadius: 1 + (auraPulse * 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: AppColors.alertRed.withValues(alpha: 0.15),
                                blurRadius: 6,
                              ),
                            ],
                    ),
                    child: Center(
                      child: Icon(
                        _micActive ? Icons.mic : Icons.mic_off,
                        size: 20,
                        color: _micActive
                            ? AppColors.cyberpunkCyan
                            : AppColors.alertRed,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Cluster: Wi-Fi status & Frontal sensor distance
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected
                      ? AppColors.cyberpunkCyan
                      : AppColors.alertRed,
                ),
                tooltip: "Rover Connection",
                onPressed: _openDialog,
              ),
              const SizedBox(width: 15),
              Row(
                children: [
                  Icon(
                    Icons.sensors,
                    color: _distance < 20
                        ? AppColors.alertRed
                        : AppColors.primaryNeon,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "$_distance CM",
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: _distance < 20
                          ? AppColors.alertRed
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right Cluster: Battery indicator, Sound Mute, Transmitting Microphone
          Row(
            children: [
              Row(
                children: [
                  Text(
                    "$_battery%",
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _getBatteryIcon(),
                    color: _getBatteryColor(),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _isMuted
                      ? AppColors.alertRed
                      : AppColors.cyberpunkCyan,
                ),
                tooltip: _isMuted ? "Unmute Audio" : "Mute Audio",
                onPressed: _toggleSpeaker,
              ),
              const SizedBox(width: 4),
              _buildMicButton(),
            ],
          ),
        ],
      ),
    );
  }
}