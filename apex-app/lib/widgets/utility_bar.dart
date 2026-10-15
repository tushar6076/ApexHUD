// lib/widgets/utility_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../styles/color.dart';
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

class _UtilityBarState extends State<UtilityBar> {
  final UdpConnector _connector = UdpConnector();
  final CommandService _cmd = CommandService();

  bool _isConnected = false;
  bool _micActive = false;
  bool _isMuted = false;
  int _battery = 100;
  int _distance = 0;

  StreamSubscription<bool>? _statusSub;
  StreamSubscription<TelemetryData>? _telemetrySub;

  @override
  void initState() {
    super.initState();
    _isConnected = _connector.isConnected;

    _statusSub = _connector.connectionStatusStream.listen((status) {
      setState(() {
        _isConnected = status;
      });
    });

    _telemetrySub = _connector.telemetryStream.listen((data) {
      setState(() {
        _battery = data.battery;
        _distance = data.distance;
      });
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _telemetrySub?.cancel();
    super.dispose();
  }

  void _openDialog() {
    SfxPlayer().playBlip();
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        backgroundColor: AppColors.darkBackground,
        content: ConnectionDialogContent(),
      ),
    );
  }

  void _toggleMic() async {
    SfxPlayer().playBlip();
    setState(() {
      _micActive = !_micActive;
    });

    if (_micActive) {
      _cmd.setMic(true);
      await MicStreamer().startStreaming();
    } else {
      await MicStreamer().stopStreaming();
      _cmd.setMic(false);
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _isMuted = SfxPlayer().toggleMute();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? AppColors.cyberpunkCyan : AppColors.alertRed,
                ),
                onPressed: _openDialog,
              ),
              const SizedBox(width: 15),
              Row(
                children: [
                  const Icon(Icons.alt_route, color: AppColors.primaryNeon, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    "$_distance M",
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text(
                "$_battery%",
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.battery_std, color: Color(0xFF99FF33), size: 18),
              const SizedBox(width: 25),
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _isMuted ? AppColors.alertRed : AppColors.cyberpunkCyan,
                ),
                onPressed: _toggleSpeaker,
              ),
              IconButton(
                icon: Icon(
                  _micActive ? Icons.mic : Icons.mic_off,
                  color: _micActive ? AppColors.cyberpunkCyan : AppColors.alertRed,
                ),
                onPressed: _toggleMic,
              ),
            ],
          ),
        ],
      ),
    );
  }
}