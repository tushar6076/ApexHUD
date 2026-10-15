// lib/widgets/control_pad.dart
import 'package:flutter/material.dart';
import '../../styles/color.dart';
import '../../services/audio/sfx_player.dart';
import '../../services/udp/command_service.dart';

class ControlPad extends StatefulWidget {
  const ControlPad({super.key});

  @override
  State<ControlPad> createState() => _ControlPadState();
}

class _ControlPadState extends State<ControlPad> with TickerProviderStateMixin {
  final CommandService _cmd = CommandService();
  final SfxPlayer _sfxPlayer = SfxPlayer();

  Offset _driveKnob = Offset.zero;
  Offset _steerKnob = Offset.zero;
  static const double _maxRadius = 60.0;
  static const double _deadZone = 18.0;

  bool _headlightOn = false;
  bool _leftIndicatorOn = false;
  bool _rightIndicatorOn = false;
  bool _hornActive = false;

  late final AnimationController _hornAnimController;
  late final Animation<double> _hornRippleScale;
  late final Animation<double> _hornRippleOpacity;
  late final Animation<double> _hornBtnScale;

  late final AnimationController _blinkAnimController;
  late final Animation<double> _blinkGlow;

  int _lastDriveDirection = 0;
  int _lastSteerDirection = 0;

  @override
  void initState() {
    super.initState();

    _hornAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _hornRippleScale = Tween<double>(begin: 1.0, end: 2.1).animate(
      CurvedAnimation(parent: _hornAnimController, curve: Curves.easeOutQuad),
    );

    _hornRippleOpacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _hornAnimController, curve: Curves.easeOutQuad),
    );

    _hornBtnScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 70),
    ]).animate(_hornAnimController);

    _blinkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _blinkGlow = CurvedAnimation(
      parent: _blinkAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _hornAnimController.dispose();
    _blinkAnimController.dispose();
    super.dispose();
  }

  void _syncBlinkController() {
    if (_leftIndicatorOn || _rightIndicatorOn) {
      _sfxPlayer.startIndicatorLoop();
      if (!_blinkAnimController.isAnimating) {
        _blinkAnimController.repeat(reverse: true);
      }
    } else {
      _sfxPlayer.stopIndicatorLoop();
      _blinkAnimController.stop();
      _blinkAnimController.reset();
    }
  }

  void _toggleLeftIndicator() {
    _sfxPlayer.playBlip();
    setState(() {
      _leftIndicatorOn = !_leftIndicatorOn;
      if (_leftIndicatorOn) {
        if (_rightIndicatorOn) {
          _rightIndicatorOn = false;
          _cmd.setRightIndicator(false);
        }
        _cmd.setLeftIndicator(true);
      } else {
        _cmd.setLeftIndicator(false);
      }
      _syncBlinkController();
    });
  }

  void _toggleRightIndicator() {
    _sfxPlayer.playBlip();
    setState(() {
      _rightIndicatorOn = !_rightIndicatorOn;
      if (_rightIndicatorOn) {
        if (_leftIndicatorOn) {
          _leftIndicatorOn = false;
          _cmd.setLeftIndicator(false);
        }
        _cmd.setRightIndicator(true);
      } else {
        _cmd.setRightIndicator(false);
      }
      _syncBlinkController();
    });
  }

  void _triggerHorn() {
    setState(() {
      _hornActive = true;
    });

    _hornAnimController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _hornActive = false;
        });
      }
    });

    _sfxPlayer.playBlip();
    _cmd.horn();
  }

  void _processDrive(Offset delta) {
    final double clampedY = delta.dy.clamp(-_maxRadius, _maxRadius);
    setState(() {
      _driveKnob = Offset(0, clampedY);
    });

    final double throttleIntensity = (clampedY.abs() / _maxRadius).clamp(0.0, 1.0);
    final double currentSteer = (_steerKnob.dx / _maxRadius).clamp(-1.0, 1.0);

    // Feed combined state to the kinematic audio mixer
    _sfxPlayer.updateControls(
      throttle: throttleIntensity,
      steer: currentSteer,
    );

    int dir = 0;
    if (clampedY < -_deadZone) {
      dir = 1;
    } else if (clampedY > _deadZone) {
      dir = -1;
    }

    if (dir != _lastDriveDirection) {
      _lastDriveDirection = dir;
      if (dir == 1) {
        _cmd.forward();
      } else if (dir == -1) {
        _cmd.backward();
      } else {
        _cmd.halt();
      }
    }
  }

  void _releaseDrive() {
    setState(() {
      _driveKnob = Offset.zero;
    });

    final double currentSteer = (_steerKnob.dx / _maxRadius).clamp(-1.0, 1.0);
    // Cut throttle target; audio mixer handles coasting momentum decay
    _sfxPlayer.updateControls(
      throttle: 0.0,
      steer: currentSteer,
    );

    _lastDriveDirection = 0;
    _cmd.halt();
  }

  void _processSteer(Offset delta) {
    final double clampedX = delta.dx.clamp(-_maxRadius, _maxRadius);
    setState(() {
      _steerKnob = Offset(clampedX, 0);
    });

    final double steerIntensity = (clampedX / _maxRadius).clamp(-1.0, 1.0);
    final double currentThrottle = (_driveKnob.dy.abs() / _maxRadius).clamp(0.0, 1.0);

    // Feed combined state to the kinematic audio mixer
    _sfxPlayer.updateControls(
      throttle: currentThrottle,
      steer: steerIntensity,
    );

    int dir = 0;
    if (clampedX < -_deadZone) {
      dir = -1;
    } else if (clampedX > _deadZone) {
      dir = 1;
    }

    if (dir != _lastSteerDirection) {
      _lastSteerDirection = dir;
      if (dir == -1) {
        _cmd.turnLeft();
      } else if (dir == 1) {
        _cmd.turnRight();
      } else {
        _cmd.halt();
      }
    }
  }

  void _releaseSteer() {
    setState(() {
      _steerKnob = Offset.zero;
    });

    final double currentThrottle = (_driveKnob.dy.abs() / _maxRadius).clamp(0.0, 1.0);
    _sfxPlayer.updateControls(
      throttle: currentThrottle,
      steer: 0.0,
    );

    _lastSteerDirection = 0;
    _cmd.halt();
  }

  Widget _buildJoystickBase({
    required Offset knobOffset,
    required GestureDragUpdateCallback onPanUpdate,
    required GestureDragEndCallback onPanEnd,
    required IconData axisIconA,
    required IconData axisIconB,
    required bool isVertical,
  }) {
    return GestureDetector(
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Container(
        width: 170,
        height: 170,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryNeon.withValues(alpha: 0.04),
          border: Border.all(
            color: AppColors.primaryNeon.withValues(alpha: 0.35),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryNeon.withValues(alpha: 0.08),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isVertical) ...[
              Positioned(
                top: 10,
                child: Icon(axisIconA,
                    size: 20,
                    color: AppColors.primaryNeon.withValues(alpha: 0.5)),
              ),
              Positioned(
                bottom: 10,
                child: Icon(axisIconB,
                    size: 20,
                    color: AppColors.primaryNeon.withValues(alpha: 0.5)),
              ),
            ] else ...[
              Positioned(
                left: 10,
                child: Icon(axisIconA,
                    size: 20,
                    color: AppColors.primaryNeon.withValues(alpha: 0.5)),
              ),
              Positioned(
                right: 10,
                child: Icon(axisIconB,
                    size: 20,
                    color: AppColors.primaryNeon.withValues(alpha: 0.5)),
              ),
            ],
            Transform.translate(
              offset: knobOffset,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkBackground,
                  border: Border.all(
                    color: AppColors.primaryNeon,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNeon.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.drag_indicator,
                    color: AppColors.primaryNeon,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHornButton() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _hornAnimController,
            builder: (context, child) {
              if (!_hornAnimController.isAnimating) {
                return const SizedBox.shrink();
              }
              return Transform.scale(
                scale: _hornRippleScale.value,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryNeon
                          .withValues(alpha: _hornRippleOpacity.value),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryNeon.withValues(
                            alpha: _hornRippleOpacity.value * 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _hornBtnScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _hornBtnScale.value,
                child: GestureDetector(
                  onTap: _triggerHorn,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hornActive
                          ? AppColors.primaryNeon
                          : AppColors.darkBackground.withValues(alpha: 0.7),
                      border: Border.all(
                        color: _hornActive
                            ? AppColors.primaryNeon
                            : AppColors.primaryNeon.withValues(alpha: 0.4),
                        width: 1.8,
                      ),
                      boxShadow: _hornActive
                          ? [
                              BoxShadow(
                                color: AppColors.primaryNeon
                                    .withValues(alpha: 0.6),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.campaign,
                      size: 22,
                      color: _hornActive ? Colors.black : AppColors.primaryNeon,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBlinkingIndicatorButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _blinkAnimController,
      builder: (context, child) {
        final double blinkFactor = active ? _blinkGlow.value : 0.0;
        final Color activeCyan = AppColors.cyberpunkCyan;

        final Color btnBg = active
            ? activeCyan.withValues(alpha: 0.25 + (blinkFactor * 0.75))
            : AppColors.darkBackground.withValues(alpha: 0.7);

        final Color borderCol = active
            ? activeCyan.withValues(alpha: 0.5 + (blinkFactor * 0.5))
            : AppColors.primaryNeon.withValues(alpha: 0.4);

        final Color iconCol = active
            ? (blinkFactor > 0.5 ? Colors.black : activeCyan)
            : AppColors.primaryNeon;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: btnBg,
              border: Border.all(
                color: borderCol,
                width: 1.8,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: activeCyan.withValues(
                            alpha: 0.2 + (blinkFactor * 0.55)),
                        blurRadius: 10 + (blinkFactor * 6),
                        spreadRadius: 1 + (blinkFactor * 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 22,
              color: iconCol,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    Color activeColor = AppColors.primaryNeon,
    Color activeIconColor = Colors.black,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              active ? activeColor : AppColors.darkBackground.withValues(alpha: 0.7),
          border: Border.all(
            color: active
                ? activeColor
                : AppColors.primaryNeon.withValues(alpha: 0.4),
            width: 1.8,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: active ? activeIconColor : AppColors.primaryNeon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Left Drive Joystick
        Positioned(
          left: 36,
          bottom: 28,
          child: _buildJoystickBase(
            knobOffset: _driveKnob,
            onPanUpdate: (details) =>
                _processDrive(details.localPosition - const Offset(85, 85)),
            onPanEnd: (_) => _releaseDrive(),
            axisIconA: Icons.keyboard_arrow_up,
            axisIconB: Icons.keyboard_arrow_down,
            isVertical: true,
          ),
        ),

        // Left Flank: Horn (with ripple) & Blinking Left Turn Indicator
        Positioned(
          left: 212,
          bottom: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHornButton(),
              const SizedBox(height: 6),
              _buildBlinkingIndicatorButton(
                icon: Icons.turn_left,
                active: _leftIndicatorOn,
                onTap: _toggleLeftIndicator,
              ),
            ],
          ),
        ),

        // Right Flank: Headlight & Blinking Right Turn Indicator
        Positioned(
          right: 220,
          bottom: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircleButton(
                icon: _headlightOn ? Icons.light_mode : Icons.flashlight_off,
                active: _headlightOn,
                onTap: () {
                  setState(() {
                    _headlightOn = !_headlightOn;
                  });
                  _sfxPlayer.playLightToggle(_headlightOn);
                  _cmd.setHeadlight(_headlightOn);
                },
              ),
              const SizedBox(height: 14),
              _buildBlinkingIndicatorButton(
                icon: Icons.turn_right,
                active: _rightIndicatorOn,
                onTap: _toggleRightIndicator,
              ),
            ],
          ),
        ),

        // Right Steering Joystick
        Positioned(
          right: 36,
          bottom: 28,
          child: _buildJoystickBase(
            knobOffset: _steerKnob,
            onPanUpdate: (details) =>
                _processSteer(details.localPosition - const Offset(85, 85)),
            onPanEnd: (_) => _releaseSteer(),
            axisIconA: Icons.chevron_left,
            axisIconB: Icons.chevron_right,
            isVertical: false,
          ),
        ),
      ],
    );
  }
}