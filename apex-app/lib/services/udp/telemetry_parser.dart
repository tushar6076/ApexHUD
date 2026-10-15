// lib/services/udp/telemetry_parser.dart
import 'dart:convert';
import '../../core/exceptions.dart';

class TelemetryData {
  final int battery;  // 0 - 100%
  final int speed;    // Speed in HM/H (hectometers per hour, e.g. 0 to 60)
  final int distance; // Distance in cm
  final DateTime timestamp;

  TelemetryData({
    required this.battery,
    required this.speed,
    required this.distance,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'TelemetryData(B: $battery%, S: $speed hm/h, D: ${distance}cm)';
}

class TelemetryParser {
  /// Parses JSON: '{"B":"85","S":"58","D":"152"}'
  /// Fallback parses pipe-delimited format: 'B:85|S:58|D:152'
  static TelemetryData parse(String rawMessage) {
    final cleaned = rawMessage.trim();
    if (cleaned.isEmpty) {
      throw TelemetryParseException("Empty packet payload");
    }

    try {
      final decoded = json.decode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return _buildFromMap(decoded);
      }
    } catch (_) {}

    try {
      final Map<String, dynamic> fallbackMap = {};
      final parts = cleaned.split('|');
      for (final part in parts) {
        final pair = part.split(':');
        if (pair.length == 2) {
          fallbackMap[pair[0].trim()] = pair[1].trim();
        }
      }

      if (fallbackMap.isNotEmpty) {
        return _buildFromMap(fallbackMap);
      }
    } catch (_) {}

    throw TelemetryParseException("Malformed telemetry packet: $cleaned");
  }

  static TelemetryData _buildFromMap(Map<String, dynamic> map) {
    int parseVal(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      return (double.tryParse(value.toString()) ?? 0).toInt();
    }

    return TelemetryData(
      battery: parseVal(map['B']).clamp(0, 100),
      speed: parseVal(map['S']).clamp(0, 200),
      distance: parseVal(map['D']).clamp(0, 999),
    );
  }
}