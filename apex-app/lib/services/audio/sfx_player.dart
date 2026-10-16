// lib/services/audio/sfx_player.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants.dart';

class SfxPlayer {
  static final SfxPlayer _instance = SfxPlayer._internal();
  factory SfxPlayer() => _instance;
  SfxPlayer._internal();

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  late final AudioPlayer _uiPlayer;
  late final AudioPlayer _hornPlayer;
  late final AudioPlayer _indicatorPlayer;
  late final AudioPlayer _idlePlayer;
  late final AudioPlayer _drivePlayer;
  late final AudioPlayer _strainPlayer;

  bool _initialized = false;
  bool _loopsStarted = false;

  // Raw joystick inputs (-1.0 to 1.0)
  double _rawDriveY = 0.0;
  double _rawSteerX = 0.0;

  // Signed Kinematics (-1.0 to 1.0)
  double _velocity = 0.0;       // Filtered signed speed
  double _steerAngle = 0.0;     // Filtered signed steering

  // Hold Durations (seconds)
  double _driveHoldSeconds = 0.0;
  double _steerHoldSeconds = 0.0;

  // Platform-Channel Cache
  double _cachedIdleVol = -1.0;
  double _cachedIdlePitch = -1.0;
  double _cachedDriveVol = -1.0;
  double _cachedDrivePitch = -1.0;
  double _cachedStrainVol = -1.0;
  double _cachedStrainPitch = -1.0;

  Timer? _physicsTicker;
  Timer? _indicatorTicker;
  bool _indicatorTickToggle = false;

  int _logTickCount = 0;
  bool enableLogs = false;

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
    _hornPlayer = _createPlayer();
    _indicatorPlayer = _createPlayer();
    _idlePlayer = _createPlayer(loop: true);
    _drivePlayer = _createPlayer(loop: true);
    _strainPlayer = _createPlayer(loop: true);

    _initialized = true;

    // 20Hz update interval (50ms delta)
    _physicsTicker?.cancel();
    _physicsTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _tickAudioPhysics(0.05);
    });
  }

  // ---------- UI One-Shots ----------

  void playHorn() {
    if (_isMuted || !_initialized) return;
    _hornPlayer.stop();
    _hornPlayer.play(AssetSource(AppConstants.sfxHorn), volume: 1.0);
  }

  void playBlip() {
    if (_isMuted || !_initialized) return;
    _uiPlayer.stop();
    _uiPlayer.setPlaybackRate(1.0);
    _uiPlayer.play(AssetSource(AppConstants.sfxUiBlip), volume: 0.7);
  }

  void playLightToggle(bool turnedOn) {
    if (_isMuted || !_initialized) return;
    _uiPlayer.stop();
    _uiPlayer.setPlaybackRate(turnedOn ? 1.25 : 0.85);
    _uiPlayer.play(AssetSource(AppConstants.sfxRelaySwitch), volume: 0.85);
  }

  // ---------- Indicator Metronome ----------

  void startIndicatorLoop() {
    if (_indicatorTicker != null || !_initialized) return;

    _indicatorTicker = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (_isMuted) return;
      _indicatorTickToggle = !_indicatorTickToggle;
      _indicatorPlayer.stop();
      _indicatorPlayer.setPlaybackRate(_indicatorTickToggle ? 1.2 : 0.9);
      _indicatorPlayer.play(
        AssetSource(AppConstants.sfxIndicatorTick),
        volume: 0.50,
      );
    });
  }

  void stopIndicatorLoop() {
    _indicatorTicker?.cancel();
    _indicatorTicker = null;
    _indicatorPlayer.stop();
  }

  // ---------- Boot & Channel Priming ----------

  void startEngineBoot() async {
    if (_isMuted || !_initialized) return;
    await _uiPlayer.play(AssetSource(AppConstants.sfxEngineStart), volume: 0.95);
    _uiPlayer.onPlayerComplete.first.then((_) {
      if (!_isMuted && _initialized) {
        _primeLoopChannels();
      }
    });
  }

  void _primeLoopChannels() {
    if (_loopsStarted) return;
    _idlePlayer.play(AssetSource(AppConstants.sfxEngineIdle), volume: 0.40);
    _drivePlayer.play(AssetSource(AppConstants.sfxEngineDrive), volume: 0.0);
    _strainPlayer.play(AssetSource(AppConstants.sfxTurnStrain), volume: 0.0);
    _loopsStarted = true;
  }

  // ---------- Inputs from ControlPad ----------

  void setDriveInput(double normalizedY) {
    _rawDriveY = normalizedY.clamp(-1.0, 1.0);
  }

  void setSteerInput(double normalizedX) {
    _rawSteerX = normalizedX.clamp(-1.0, 1.0);
  }

  // ---------- Smooth S-Curve Helper ----------
  double _smoothStep(double edge0, double edge1, double x) {
    final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  // ---------- Kinematics Physics Loop ----------

  void _tickAudioPhysics(double dt) {
    if (_isMuted || !_initialized || !_loopsStarted) return;

    // 1. Resolve Command Intent with Deadbands
    double targetThrottleSigned = 0.0;
    if (_rawDriveY < -0.15) {
      targetThrottleSigned = (_rawDriveY.abs() - 0.15) / 0.85; // Forward (+1.0)
    } else if (_rawDriveY > 0.15) {
      targetThrottleSigned = -((_rawDriveY - 0.15) / 0.85);    // Reverse (-1.0)
    }

    double targetSteerSigned = 0.0;
    if (_rawSteerX.abs() > 0.15) {
      targetSteerSigned = (_rawSteerX.sign) * ((_rawSteerX.abs() - 0.15) / 0.85);
    }

    // 2. Track Continuous Stick Hold Duration
    if (targetThrottleSigned != 0.0) {
      _driveHoldSeconds += dt;
    } else {
      _driveHoldSeconds = (_driveHoldSeconds - dt * 2.0).clamp(0.0, 10.0);
    }

    if (targetSteerSigned != 0.0) {
      _steerHoldSeconds += dt;
    } else {
      _steerHoldSeconds = (_steerHoldSeconds - dt * 2.0).clamp(0.0, 10.0);
    }

    // 3. Ultra-Smooth Kinetic Momentum (S-Curved Accel + Drag)
    final bool isBraking = (targetThrottleSigned > 0 && _velocity < -0.05) ||
        (targetThrottleSigned < 0 && _velocity > 0.05);

    if (isBraking) {
      // Counter-throttle applies progressive braking
      _velocity += (_velocity > 0 ? -1.0 : 1.0) * (0.45 * dt * 20);
    } else if (targetThrottleSigned != 0.0) {
      // S-Curve based acceleration: soft initial spool, firm mid-range, gentle top-end
      final double progress = _smoothStep(0.0, 1.0, _velocity.abs());
      final double accelRate = 0.06 + (progress * 0.14) + (_driveHoldSeconds * 0.04).clamp(0.0, 0.12);
      _velocity += (targetThrottleSigned - _velocity) * accelRate;
    } else {
      // Fluid coast-down
      _velocity += (0.0 - _velocity) * 0.065;
    }

    if (_velocity.abs() < 0.005) _velocity = 0.0;
    _velocity = _velocity.clamp(-1.0, 1.0);

    // 4. Directional Steering Accumulation
    final bool steerDirChanged = (_steerAngle > 0.05 && targetSteerSigned < -0.05) ||
        (_steerAngle < -0.05 && targetSteerSigned > 0.05);

    if (steerDirChanged) {
      _steerAngle += (0.0 - _steerAngle) * 0.40;
    } else if (targetSteerSigned != 0.0) {
      final double steerRate = 0.14 + (_steerHoldSeconds * 0.08).clamp(0.0, 0.20);
      _steerAngle += (targetSteerSigned - _steerAngle) * steerRate;
    } else {
      _steerAngle += (0.0 - _steerAngle) * 0.20;
    }

    if (_steerAngle.abs() < 0.005) _steerAngle = 0.0;
    _steerAngle = _steerAngle.clamp(-1.0, 1.0);

    final double speedAbs = _velocity.abs();
    final double steerAbs = _steerAngle.abs();

    // -------------------------------------------------------------
    // CHANNEL 1: Idle Engine Ambient
    // -------------------------------------------------------------
    final double loadRatio = (speedAbs * 0.75 + steerAbs * 0.25).clamp(0.0, 1.0);
    final double targetIdleVol = (0.40 - (loadRatio * 0.30)).clamp(0.06, 0.40);

    _applyParam(
      player: _idlePlayer,
      newVol: targetIdleVol,
      newPitch: 1.0,
      cachedVol: _cachedIdleVol,
      cachedPitch: _cachedIdlePitch,
      pitchThreshold: 0.20,
      onUpdate: (v, p) {
        _cachedIdleVol = v;
        _cachedIdlePitch = p;
      },
    );

    // -------------------------------------------------------------
    // CHANNEL 2: Drive Engine (Ultra-Smooth Low-to-High RPM)
    // -------------------------------------------------------------
    double targetDriveVol = 0.0;
    const double pitchFloor = 0.22; // Sub-bass initial floor
    double targetDrivePitch = pitchFloor;

    if (speedAbs > 0.005 || targetThrottleSigned.abs() > 0.05) {
      final double throttleDemand = targetThrottleSigned.abs();

      // Fluid blended motor load
      final double motorLoad = (speedAbs * 0.72 + throttleDemand * 0.28).clamp(0.0, 1.0);

      // Volume ramps smoothly via power curve (no step jump)
      final double holdVolBonus = (_driveHoldSeconds * 0.12).clamp(0.0, 0.18);
      targetDriveVol = ((math.pow(motorLoad, 1.35) * 0.88) + holdVolBonus).clamp(0.0, 1.0);

      // Pitch strictly follows speed with exponential curvature
      final double maxPitch = _velocity < 0 ? 1.45 : 2.25;
      final double speedRatioExp = math.pow(speedAbs, 1.95).toDouble();
      final double holdPitchBonus = (_driveHoldSeconds * 0.05).clamp(0.0, 0.12);

      targetDrivePitch = (pitchFloor + (speedRatioExp * (maxPitch - pitchFloor)) + holdPitchBonus)
          .clamp(pitchFloor, maxPitch);
    }

    _applyParam(
      player: _drivePlayer,
      newVol: targetDriveVol,
      newPitch: targetDrivePitch,
      cachedVol: _cachedDriveVol,
      cachedPitch: _cachedDrivePitch,
      pitchThreshold: 0.04,
      onUpdate: (v, p) {
        _cachedDriveVol = v;
        _cachedDrivePitch = p;
      },
    );

    // -------------------------------------------------------------
    // CHANNEL 3: Turn Strain (Coupled Directly to Acceleration/Speed)
    // -------------------------------------------------------------
    double targetStrainVol = 0.0;
    const double strainPitchFloor = 0.32; // Deep low pitch at near-zero speed
    double targetStrainPitch = strainPitchFloor;

    if (steerAbs > 0.02) {
      if (speedAbs < 0.10) {
        // [STATIONARY / LOW-SPEED PIVOT]:
        // Volume is strictly capped at a subtle mechanical hum (0.04 -> 0.08)
        // Pitch stays locked at a deep sub-frequency (0.32x)
        final double pivotRatio = (speedAbs / 0.10);
        targetStrainVol = (steerAbs * (0.04 + pivotRatio * 0.04)).clamp(0.0, 0.08);
        targetStrainPitch = strainPitchFloor + (pivotRatio * 0.08);
      } else {
        // [HIGH-SPEED MOVING CORNERING]:
        // Pitch and volume roar proportionally to velocity * steer
        final double speedScrub = speedAbs * math.pow(steerAbs, 1.25);
        final double holdStrainBonus = (_steerHoldSeconds * 0.15).clamp(0.0, 0.20);

        // Volume builds aggressively as speed increases
        targetStrainVol = (0.08 + (speedScrub * 0.82) + holdStrainBonus).clamp(0.0, 0.95);

        // Pitch sweeps up from 0.45x to 1.90x based on kinetic speed and turn angle
        final double maxStrainPitch = 1.90;
        final double dynamicPitchRamp = math.pow(speedAbs, 1.4) * steerAbs;
        targetStrainPitch = (0.45 + (dynamicPitchRamp * (maxStrainPitch - 0.45)) + (_steerHoldSeconds * 0.05))
            .clamp(0.40, maxStrainPitch);
      }
    }

    _applyParam(
      player: _strainPlayer,
      newVol: targetStrainVol,
      newPitch: targetStrainPitch,
      cachedVol: _cachedStrainVol,
      cachedPitch: _cachedStrainPitch,
      pitchThreshold: 0.04,
      onUpdate: (v, p) {
        _cachedStrainVol = v;
        _cachedStrainPitch = p;
      },
    );

    // Diagnostics
    if (enableLogs && (speedAbs > 0.01 || steerAbs > 0.01)) {
      _logTickCount++;
      if (_logTickCount % 20 == 0) {
        // ignore: avoid_print
        print(
          "[AUDIO KINEMATICS] Vel: ${(_velocity * 100).toInt()}% (Hold: ${_driveHoldSeconds.toStringAsFixed(1)}s) | "
          "Steer: ${(_steerAngle * 100).toInt()}% (Hold: ${_steerHoldSeconds.toStringAsFixed(1)}s) | "
          "Drive: [v: ${targetDriveVol.toStringAsFixed(2)}, p: ${targetDrivePitch.toStringAsFixed(2)}x] | "
          "Strain: [v: ${targetStrainVol.toStringAsFixed(2)}, p: ${targetStrainPitch.toStringAsFixed(2)}x]",
        );
      }
    }
  }

  void _applyParam({
    required AudioPlayer player,
    required double newVol,
    required double newPitch,
    required double cachedVol,
    required double cachedPitch,
    required void Function(double v, double p) onUpdate,
    double pitchThreshold = 0.04,
  }) {
    final bool volChanged = (newVol - cachedVol).abs() > 0.02 || (newVol == 0.0 && cachedVol != 0.0);
    final bool pitchChanged = (newPitch - cachedPitch).abs() > pitchThreshold;

    if (volChanged) {
      player.setVolume(newVol);
    }
    if (pitchChanged && newVol > 0.005) {
      player.setPlaybackRate(newPitch);
    }

    if (volChanged || pitchChanged) {
      onUpdate(newVol, newPitch);
    }
  }

  bool toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stopAll();
    } else {
      _primeLoopChannels();
    }
    return _isMuted;
  }

  void stopAll() {
    stopIndicatorLoop();
    _uiPlayer.stop();
    _hornPlayer.stop();
    _indicatorPlayer.stop();
    _idlePlayer.stop();
    _drivePlayer.stop();
    _strainPlayer.stop();
    _velocity = 0.0;
    _steerAngle = 0.0;
    _driveHoldSeconds = 0.0;
    _steerHoldSeconds = 0.0;
    _rawDriveY = 0.0;
    _rawSteerX = 0.0;
    _cachedIdleVol = -1.0;
    _cachedDriveVol = -1.0;
    _cachedStrainVol = -1.0;
    _loopsStarted = false;
  }

  void dispose() {
    _physicsTicker?.cancel();
    stopIndicatorLoop();
    stopAll();
    _uiPlayer.dispose();
    _hornPlayer.dispose();
    _indicatorPlayer.dispose();
    _idlePlayer.dispose();
    _drivePlayer.dispose();
    _strainPlayer.dispose();
    _initialized = false;
  }
}