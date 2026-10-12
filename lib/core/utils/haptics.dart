import 'package:flutter/services.dart';

/// Central haptic feedback for taps and selections.
class AppHaptics {
  const AppHaptics._();

  static Future<void> tap() => HapticFeedback.lightImpact();

  static Future<void> selection() => HapticFeedback.selectionClick();

  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Rising tick during a long hold — denser / heavier as [progress] → 1.
  static Future<void> holdTick(double progress) async {
    try {
      final t = progress.clamp(0.0, 1.0);
      if (t >= 0.9) {
        await HapticFeedback.heavyImpact();
      } else if (t >= 0.7) {
        await HapticFeedback.mediumImpact();
      } else if (t >= 0.4) {
        await HapticFeedback.lightImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {
      /* iOS Simulator has no Taptic Engine */
    }
  }

  /// Strong, longer confirmation burst when a hold completes.
  static Future<void> holdConfirm() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 55));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 55));
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 45));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.selectionClick();
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await HapticFeedback.vibrate();
    } catch (_) {
      /* iOS Simulator has no Taptic Engine */
    }
  }

  /// Wraps a press handler so every tap fires light haptic first.
  static VoidCallback? wrap(VoidCallback? onPressed) {
    if (onPressed == null) return null;
    return () {
      tap();
      onPressed();
    };
  }

  /// Wraps value-change handlers (chips, dropdowns, toggles).
  static ValueChanged<T>? wrapChanged<T>(ValueChanged<T>? onChanged) {
    if (onChanged == null) return null;
    return (value) {
      selection();
      onChanged(value);
    };
  }

  /// Big success burst after payment — heavy hits plus a click run.
  static Future<void> celebrate() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 45));
      for (var i = 0; i < 4; i++) {
        await HapticFeedback.selectionClick();
        await Future<void>.delayed(const Duration(milliseconds: 38));
      }
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 110));
      await HapticFeedback.mediumImpact();
      await HapticFeedback.vibrate();
    } catch (_) {
      /* iOS Simulator has no Taptic Engine */
    }
  }
}
