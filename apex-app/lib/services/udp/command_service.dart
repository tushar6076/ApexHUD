// lib/services/udp/command_service.dart
import '../../core/constants.dart';
import 'udp_connector.dart';

class CommandService {
  static final CommandService _instance = CommandService._internal();
  factory CommandService() => _instance;
  CommandService._internal();

  final UdpConnector _connector = UdpConnector();

  bool get isConnected => _connector.isConnected;

  void forward() => send(AppConstants.cmdForward);
  void backward() => send(AppConstants.cmdBackward);
  void turnLeft() => send(AppConstants.cmdLeft);
  void turnRight() => send(AppConstants.cmdRight);
  void halt() => send(AppConstants.cmdHalt);

  void horn() => send(AppConstants.cmdHorn);
  void setHeadlight(bool state) =>
      send(state ? AppConstants.cmdHeadlightOn : AppConstants.cmdHeadlightOff);

  void setLeftIndicator(bool state) =>
      send(state ? AppConstants.cmdIndicatorLeftOn : AppConstants.cmdIndicatorLeftOff);

  void setRightIndicator(bool state) =>
      send(state ? AppConstants.cmdIndicatorRightOn : AppConstants.cmdIndicatorRightOff);

  void setMic(bool state) =>
      send(state ? AppConstants.cmdMicOn : AppConstants.cmdMicOff);

  void ping() => send(AppConstants.cmdPing);

  void send(String cmd) {
    _connector.sendCommand(cmd);
  }
}