// lib/core/config.dart
class Config {
  static const String espIp = "192.168.4.1";
  static const int udpPort = 4210;
  static const int telemetryPort = 4210;
  static const int voicePort = 8081;
  static const String robotName = "APEX_ROVER";
}

class DevelopmentConfig extends Config {
  static const bool debug = true;
}

class ProductionConfig extends Config {
  static const bool debug = false;
}