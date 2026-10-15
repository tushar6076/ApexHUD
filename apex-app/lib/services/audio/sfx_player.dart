// lib/services/audio/sfx_player.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants.dart';

class SfxPlayer {
  static final SfxPlayer _instance = SfxPlayer._internal();
  factory SfxPlayer() => _instance;
  SfxPlayer._internal();

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  // Dedicated Audio Channels
  late final AudioPlayer _uiPlayer;        // Clicks, switches, relay
  late final AudioPlayer _indicatorPlayer; // Metronome blinker ticks
  late final AudioPlayer _idlePlayer;      // Ambient cabin / idle drone
  late final AudioPlayer _drivePlayer;     // High-frequency motor whine / RPM
  late final AudioPlayer _servoPlayer;     // Steering servo actuation

  bool _initialized = false;

  // Kinematic Sound State
  double _currentMomentum = 0.0; // 0.0 -> 1.0 (smooth vehicle speed)
  double _targetThrottle = 0.0;  // Commanded joystick throttle
  double _targetSteer = 0.0;     // Commanded steer intensity (-1.0 to 1.0)
  Timer? _physicsTicker;
  Timer? _indicatorTicker;
  bool _indicatorTickToggle = false;

  AudioPlayer _createPlayer({bool loop = false}) {
    final player = AudioPlayer();
    player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
    player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    return player;
  }

  void initialize() {
    if (_initialized) return;

    _uiPlayer = _createPlayer();
    _indicatorPlayer = _createPlayer();
    _servoPlayer = _createPlayer();
    _idlePlayer = _createPlayer(loop: true);
    _drivePlayer = _createPlayer(loop: true);

    _initialized = true;

    // Start 30Hz vehicle sound physics mixer loop (every 33ms)
    _physicsTicker?.cancel();
    _physicsTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _tickAudioPhysics();
    });
  }

  // ---------- 1 & 2. Transient UI & Switch Sounds ----------

  void playBlip() {
    if (_isMuted || !_initialized) return;
    _uiPlayer.stop();
    _uiPlayer.setPlaybackRate(1.0);
    _uiPlayer.play(AssetSource(AppConstants.sfxUiBlip), volume: 0.7);
  }

  void playLightToggle(bool turnedOn) {
    if (_isMuted || !_initialized) return;
    _uiPlayer.stop();
    // Use tactile relay switch SFX; pitch shift up on engagement, down on cut
    _uiPlayer.setPlaybackRate(turnedOn ? 1.25 : 0.85);
    _uiPlayer.play(AssetSource(AppConstants.sfxRelaySwitch), volume: 0.85);
  }

  // ---------- 3. Indicators (Tick-Tock Metronome) ----------

  void startIndicatorLoop() {
    if (_indicatorTicker != null || !_initialized) return;

    _indicatorTicker = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (_isMuted) return;
      _indicatorTickToggle = !_indicatorTickToggle;
      _indicatorPlayer.stop();
      // Tick (higher pitch) vs Tock (lower pitch)
      _indicatorPlayer.setPlaybackRate(_indicatorTickToggle ? 1.2 : 0.9);
      _indicatorPlayer.play(
        AssetSource(AppConstants.sfxIndicatorTick),
        volume: 0.45,
      );
    });
  }

  void stopIndicatorLoop() {
    _indicatorTicker?.cancel();
    _indicatorTicker = null;
    _indicatorPlayer.stop();
  }

  // ---------- 4. Background & Cabin Engine Loop ----------

  void startEngineBoot() async {
    if (_isMuted || !_initialized) return;
    await _uiPlayer.play(AssetSource(AppConstants.sfxEngineStart), volume: 0.9);
    _uiPlayer.onPlayerComplete.first.then((_) {
      if (!_isMuted) {
        _idlePlayer.play(AssetSource(AppConstants.sfxEngineIdle), volume: 0.35);
        _drivePlayer.play(AssetSource(AppConstants.sfxServoFizz), volume: 0.0);
      }
    });
  }

  // ---------- 5 & 6. Kinematic Acceleration + Steering Mixer ----------

  /// Called directly from joystick pan handlers (pass normalized 0.0 to 1.0 values)
  void updateControls({required double throttle, required double steer}) {
    _targetThrottle = throttle.clamp(0.0, 1.0);
    _targetSteer = steer.clamp(-1.0, 1.0);
  }

  /// 30Hz Internal Physics Engine that handles momentum, load, and dynamic pitch
  void _tickAudioPhysics() {
    if (_isMuted || !_initialized) return;

    // Simulate inertia: accelerating is faster than natural rolling coast/drag
    if (_targetThrottle > _currentMomentum) {
      _currentMomentum += (_targetThrottle - _currentMomentum) * 0.18; // Acceleration rate
    } else {
      _currentMomentum += (_targetThrottle - _currentMomentum) * 0.07; // Coasting deceleration
    }

    if (_currentMomentum < 0.01) _currentMomentum = 0.0;

    final double steerStrain = _targetSteer.abs();

    // TOTAL ACOUSTIC MOTOR LOAD:
    // Moving + Turning creates differential strain on motors.
    // Turning on spot (0 momentum) generates pure steering servo pitch.
    final double totalLoad = (_currentMomentum * 0.75 + steerStrain * 0.35).clamp(0.0, 1.0);

    if (totalLoad <= 0.02) {
      _drivePlayer.setVolume(0.0);
      _servoPlayer.setVolume(0.0);
      _idlePlayer.setVolume(0.35);
      _idlePlayer.setPlaybackRate(1.0);
      return;
    }

    // Engine Idle attenuates when high-RPM drive whine kicks in
    _idlePlayer.setVolume((0.35 - (totalLoad * 0.25)).clamp(0.08, 0.35));
    _idlePlayer.setPlaybackRate(1.0 + (totalLoad * 0.4)); // Idle pitch rises slightly

    // Drive Motor Whine (Dynamic Pitch Shift)
    // At low throttle: 0.8x pitch. At full throttle: 1.85x pitch.
    _drivePlayer.setVolume((totalLoad * 0.85).clamp(0.0, 0.9));
    _drivePlayer.setPlaybackRate((0.75 + (totalLoad * 1.1)).clamp(0.5, 2.0));

    // Dedicated Servo Fizz for high-angle turns
    if (steerStrain > 0.2) {
      _servoPlayer.setVolume((steerStrain * 0.5).clamp(0.0, 0.6));
      _servoPlayer.setPlaybackRate(1.0 + (steerStrain * 0.5));
    } else {
      _servoPlayer.setVolume(0.0);
    }
  }

  bool toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stopAll();
    } else {
      _idlePlayer.play(AssetSource(AppConstants.sfxEngineIdle), volume: 0.35);
      _drivePlayer.play(AssetSource(AppConstants.sfxServoFizz), volume: 0.0);
    }
    return _isMuted;
  }

  void stopAll() {
    stopIndicatorLoop();
    _uiPlayer.stop();
    _indicatorPlayer.stop();
    _servoPlayer.stop();
    _idlePlayer.stop();
    _drivePlayer.stop();
    _currentMomentum = 0.0;
  }

  void dispose() {
    _physicsTicker?.cancel();
    stopIndicatorLoop();
    stopAll();
    _uiPlayer.dispose();
    _indicatorPlayer.dispose();
    _servoPlayer.dispose();
    _idlePlayer.dispose();
    _drivePlayer.dispose();
    _initialized = false;
  }
}