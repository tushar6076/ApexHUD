// lib/styles/animate.dart
import 'package:flutter/material.dart';

class AppAnimations {
  // Durations
  static const Duration hornPulseDuration = Duration(milliseconds: 400);
  static const Duration blinkCycleDuration = Duration(milliseconds: 450);
  static const Duration hudTransitionDuration = Duration(milliseconds: 600);
  static const Duration bootSequenceDelay = Duration(milliseconds: 2400);
  static const Duration micPulseDuration = Duration(milliseconds: 1200);

  // Curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve hornPulseCurve = Curves.easeOutQuad;
  static const Curve micPulseCurve = Curves.easeInOutSine;
  static const Curve micWaveCurve = Curves.easeOutCubic;

  // Horn Animation Builders
  static Animation<double> hornRippleScale(AnimationController controller) {
    return Tween<double>(begin: 1.0, end: 2.1).animate(
      CurvedAnimation(parent: controller, curve: hornPulseCurve),
    );
  }

  static Animation<double> hornRippleOpacity(AnimationController controller) {
    return Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: controller, curve: hornPulseCurve),
    );
  }

  static Animation<double> hornButtonScale(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 70),
    ]).animate(controller);
  }

  // Turn Indicator Blinker Animation Builder
  static Animation<double> blinkGlow(AnimationController controller) {
    return CurvedAnimation(parent: controller, curve: defaultCurve);
  }

  // Microphone Active Broadcast Animations
  // Radial expanding wave 1
  static Animation<double> micWaveformScalePrimary(AnimationController controller) {
    return Tween<double>(begin: 0.9, end: 1.85).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.75, curve: micWaveCurve),
      ),
    );
  }

  static Animation<double> micWaveformOpacityPrimary(AnimationController controller) {
    return Tween<double>(begin: 0.75, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );
  }

  // Radial expanding wave 2 (Phase shifted)
  static Animation<double> micWaveformScaleSecondary(AnimationController controller) {
    return Tween<double>(begin: 0.9, end: 2.4).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.25, 1.0, curve: micWaveCurve),
      ),
    );
  }

  static Animation<double> micWaveformOpacitySecondary(AnimationController controller) {
    return Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  // Core icon breathing aura and scale pop
  static Animation<double> micAuraPulse(AnimationController controller) {
    return Tween<double>(begin: 0.35, end: 0.95).animate(
      CurvedAnimation(parent: controller, curve: micPulseCurve),
    );
  }

  static Animation<double> micCoreScale(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: controller, curve: micPulseCurve));
  }
}