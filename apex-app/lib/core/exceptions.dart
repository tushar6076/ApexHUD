// lib/core/exceptions.dart
class TelemetryParseException implements Exception {
  final String message;
  TelemetryParseException(this.message);

  @override
  String toString() => "TelemetryParseException: $message";
}

class ConnectionTimeoutException implements Exception {
  final String message;
  ConnectionTimeoutException(this.message);

  @override
  String toString() => "ConnectionTimeoutException: $message";
}

class SocketTransmissionException implements Exception {
  final String message;
  SocketTransmissionException(this.message);

  @override
  String toString() => "SocketTransmissionException: $message";
}

class AudioStreamException implements Exception {
  final String message;
  AudioStreamException(this.message);

  @override
  String toString() => "AudioStreamException: $message";
}