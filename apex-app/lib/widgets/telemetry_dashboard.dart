// lib/widgets/telemetry_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../styles/color.dart';
import '../../services/udp/udp_connector.dart';
import '../../services/udp/telemetry_parser.dart';

class TelemetryDashboard extends StatefulWidget {
  const TelemetryDashboard({super.key});

  @override
  State<TelemetryDashboard> createState() => _TelemetryDashboardState();
}

class _TelemetryDashboardState extends State<TelemetryDashboard> {
  final UdpConnector _connector = UdpConnector();
  int _speed = 0;
  int _elapsedSeconds = 0;
  Timer? _missionTimer;
  StreamSubscription<TelemetryData>? _telemetrySub;
  StreamSubscription<bool>? _statusSub;

  @override
  void initState() {
    super.initState();
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connector.isConnected) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });

    _telemetrySub = _connector.telemetryStream.listen((data) {
      setState(() {
        _speed = data.speed;
      });
    });

    _statusSub = _connector.connectionStatusStream.listen((connected) {
      if (!connected) {
        setState(() {
          _elapsedSeconds = 0;
          _speed = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _missionTimer?.cancel();
    _telemetrySub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final hours = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formattedTime,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 16,
            color: AppColors.primaryNeon,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "$_speed",
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 70,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Text(
          "HM/H",
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 14,
            letterSpacing: 2.0,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}