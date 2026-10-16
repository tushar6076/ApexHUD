// lib/core/constants.dart

class AppConstants {
  // Network & Heartbeat Timeouts
  static const Duration connectionTimeout = Duration(seconds: 3);
  static const Duration telemetryInterval = Duration(seconds: 1);
  static const Duration pingInterval = Duration(seconds: 1);

  // Buffer Allocations
  static const int udpBufferSize = 1024;
  static const int voiceChunkSize = 1024;
  static const int voiceSampleRate = 8000;

  // Command Protocols
  static const String cmdForward = "F";
  static const String cmdBackward = "B";
  static const String cmdLeft = "L";
  static const String cmdRight = "R";
  static const String cmdHalt = "H";
  static const String cmdHorn = "S";
  static const String cmdHeadlightOn = "X";
  static const String cmdHeadlightOff = "x";
  static const String cmdIndicatorLeftOn = "I";
  static const String cmdIndicatorLeftOff = "i";
  static const String cmdIndicatorRightOn = "O";
  static const String cmdIndicatorRightOff = "o";
  static const String cmdMicOn = "Z";
  static const String cmdMicOff = "z";
  static const String cmdPing = "P";

  // SFX Asset Paths (relative to 'assets/')
  static const String sfxHorn = 'sfx/horn.wav';
  static const String sfxUiBlip = 'sfx/ui_blip.wav';
  static const String sfxRelaySwitch = 'sfx/relay_switch.wav';
  static const String sfxIndicatorTick = 'sfx/indicator_tick.wav';
  static const String sfxEngineDrive = 'sfx/engine_drive.wav';
  static const String sfxTurnStrain = 'sfx/turn_strain.wav';
  static const String sfxEngineStart = 'sfx/engine_start.wav';
  static const String sfxEngineIdle = 'sfx/engine_idle.wav';

  // Visual Assets
  static const String lottieLoading = 'assets/lottie/loading.json';
  static const String imgHudBackground = 'assets/images/image.jpg';
  static const String iconApp = 'assets/icons/icon.png';
  static const String iconFg = 'assets/icons/icon_fg.png';
  static const String iconBg = 'assets/icons/icon_bg.png';
}