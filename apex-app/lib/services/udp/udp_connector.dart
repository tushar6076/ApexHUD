import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/config.dart';
import '../../core/constants.dart';
import '../../core/exceptions.dart';
import 'telemetry_parser.dart';

class UdpConnector {
  static final UdpConnector _instance = UdpConnector._internal();
  factory UdpConnector() => _instance;
  UdpConnector._internal();

  RawDatagramSocket? _socket;

  String _targetIp = Config.espIp;
  int _targetPort = Config.udpPort;
  final int _listenPort = Config.telemetryPort;

  DateTime? _lastPacketTime;
  Timer? _heartbeatTimer;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  final StreamController<TelemetryData> _telemetryController =
      StreamController<TelemetryData>.broadcast();
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  void configureTarget({String? ip, int? port}) {
    if (ip != null) _targetIp = ip;
    if (port != null) _targetPort = port;
  }

  /// Binds UDP socket, listens for packets, and begins connection supervision
  Future<void> connect() async {
    await disconnect();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _listenPort,
        reuseAddress: true,
        reusePort: true,
      );

      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram != null) {
              _handleIncomingDatagram(datagram);
            }
          }
        },
        onError: (err) {
          _setConnectionState(false);
          throw SocketTransmissionException("Socket stream error: $err");
        },
        onDone: () => _setConnectionState(false),
      );

      // Start supervisor timer: sends periodic Pings and checks timeout
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(AppConstants.pingInterval, (_) {
        ping();
        _evaluateHeartbeat();
      });
    } catch (e) {
      _setConnectionState(false);
      throw SocketTransmissionException(
          "Failed to bind socket on port $_listenPort: $e");
    }
  }

  void _handleIncomingDatagram(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data).trim();
      final telemetry = TelemetryParser.parse(message);

      _lastPacketTime = DateTime.now();
      _setConnectionState(true);
      _telemetryController.add(telemetry);
    } catch (_) {
      // If packet wasn't telemetry (e.g., pong ack), update heartbeat if from target
      if (datagram.address.address == _targetIp) {
        _lastPacketTime = DateTime.now();
        _setConnectionState(true);
      }
    }
  }

  void _evaluateHeartbeat() {
    if (_lastPacketTime == null) {
      _setConnectionState(false);
      return;
    }

    final elapsed = DateTime.now().difference(_lastPacketTime!);
    if (elapsed > AppConstants.connectionTimeout) {
      _setConnectionState(false);
    }
  }

  void _setConnectionState(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionStatusController.add(connected);
    }
  }

  /// Sends a raw string command to APEC_ROVER
  void sendCommand(String cmd) {
    if (_socket == null) return;
    try {
      final target = InternetAddress(_targetIp);
      final bytes = utf8.encode(cmd);
      _socket!.send(bytes, target, _targetPort);
    } catch (_) {
      // Fire-and-forget; packet drops are handled by supervisor timeout
    }
  }

  void ping() => sendCommand(AppConstants.cmdPing);

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket?.close();
    _socket = null;
    _lastPacketTime = null;
    _setConnectionState(false);
  }

  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _telemetryController.close();
  }
}