import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';
import 'app_modal_sheet.dart';

enum HoldButtonSize { sm, md, lg }

enum HoldFillDirection { right, up }

/// Flutter port of [React Bits HoldButton](https://reactbits.dev/micro/hold-button).
/// Liquid fill + wave crest + glow, with progressive hold haptics.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    this.label = 'Hold to delete',
    this.doneLabel = 'Deleted',
    this.icon,
    this.doneIcon,
    this.backgroundColor = const Color(0xFF27272A),
    this.fillColor = const Color(0xFF5227FF),
    this.textColor = const Color(0xFFF5F5F5),
    this.fillTextColor = Colors.white,
    this.size = HoldButtonSize.md,
    this.radius = 14,
    this.fillDirection = HoldFillDirection.right,
    this.holdTime = const Duration(milliseconds: 2000),
    this.releaseTime = const Duration(milliseconds: 200),
    this.pressScale = 0.97,
    this.wave = true,
    this.waveAmplitude = 6,
    this.glow = true,
    this.resetAfter = const Duration(milliseconds: 1200),
    this.disabled = false,
    this.expanded = false,
    this.onHold,
    this.onTap,
  });

  final String label;
  final String doneLabel;
  final Widget? icon;
  final Widget? doneIcon;
  final Color backgroundColor;
  final Color fillColor;
  final Color textColor;
  final Color fillTextColor;
  final HoldButtonSize size;
  final double radius;
  final HoldFillDirection fillDirection;
  final Duration holdTime;
  final Duration releaseTime;
  final double pressScale;
  final bool wave;
  final double waveAmplitude;
  final bool glow;
  final Duration resetAfter;
  final bool disabled;
  final bool expanded;
  final VoidCallback? onHold;
  final VoidCallback? onTap;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with TickerProviderStateMixin {
  static const _tapMs = 250.0;
  static const _cycles = 2.0;

  late final AnimationController _progress;
  late final AnimationController _pulse;
  var _phase = _HoldPhase.idle;
  DateTime? _holdStartedAt;
  int _lastHapticBucket = -1;
  Timer? _resetTimer;

  double get _height => switch (widget.size) {
        HoldButtonSize.sm => 36,
        HoldButtonSize.md => 44,
        HoldButtonSize.lg => 52,
      };

  EdgeInsets get _padding => switch (widget.size) {
        HoldButtonSize.sm => const EdgeInsets.symmetric(horizontal: 16),
        HoldButtonSize.md => const EdgeInsets.symmetric(horizontal: 22),
        HoldButtonSize.lg => const EdgeInsets.symmetric(horizontal: 28),
      };

  double get _fontSize => switch (widget.size) {
        HoldButtonSize.sm => 13,
        HoldButtonSize.md => 15,
        HoldButtonSize.lg => 17,
      };

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this)
      ..addListener(_onProgressTick)
      ..addStatusListener(_onProgressStatus);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onProgressTick() {
    if (_phase != _HoldPhase.holding) return;
    // ~32 ticks across the hold → continuous rising feedback for long presses.
    final bucket = (_progress.value * 32).floor();
    if (bucket != _lastHapticBucket && bucket > 0) {
      _lastHapticBucket = bucket;
      unawaited(AppHaptics.holdTick(_progress.value));
    }
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_phase != _HoldPhase.holding) return;
    _complete();
  }

  Future<void> _beginHold() async {
    if (widget.disabled || _phase != _HoldPhase.idle) return;
    _resetTimer?.cancel();
    _holdStartedAt = DateTime.now();
    _lastHapticBucket = -1;
    setState(() => _phase = _HoldPhase.holding);
    await HapticFeedback.mediumImpact();
    _progress.duration = widget.holdTime;
    _progress.forward(from: 0);
  }

  void _cancelHold({required bool drifted}) {
    if (_phase != _HoldPhase.holding) return;
    final held = _holdStartedAt == null
        ? 0.0
        : DateTime.now().difference(_holdStartedAt!).inMilliseconds.toDouble();
    setState(() => _phase = _HoldPhase.idle);
    _progress.duration = widget.releaseTime;
    unawaited(_progress.animateTo(0, curve: Curves.easeOutCubic));
    HapticFeedback.lightImpact();
    if (!drifted && held < _tapMs) widget.onTap?.call();
  }

  Future<void> _complete() async {
    if (_phase != _HoldPhase.holding) return;
    setState(() => _phase = _HoldPhase.done);
    await AppHaptics.holdConfirm();
    if (widget.glow) {
      _pulse
        ..value = 0
        ..forward();
    }
    widget.onHold?.call();
    if (widget.resetAfter > Duration.zero) {
      _resetTimer?.cancel();
      _resetTimer = Timer(widget.resetAfter, () {
        if (!mounted) return;
        setState(() => _phase = _HoldPhase.idle);
        _progress.duration = widget.releaseTime;
        unawaited(_progress.animateTo(0, curve: Curves.easeOutCubic));
      });
    }
  }

  Widget _labelRow({
    required Color color,
    required bool done,
  }) {
    final icon = done
        ? (widget.doneIcon ??
            Icon(Iconsax.tick_circle, size: _fontSize + 2, color: color))
        : (widget.icon ??
            Icon(Iconsax.trash, size: _fontSize + 2, color: color));
    final text = done ? widget.doneLabel : widget.label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.01 * _fontSize,
            color: color,
            height: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final holding = _phase == _HoldPhase.holding;
    final done = _phase == _HoldPhase.done;
    final scale = holding ? widget.pressScale : 1.0;
    final glowAlpha = holding || done ? 0.55 : 0.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedBuilder(
        animation: Listenable.merge([_progress, _pulse]),
        builder: (context, _) {
          final p = _progress.value.clamp(0.0, 1.0);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: widget.disabled
                ? null
                : (_) => _beginHold(),
            onPointerUp: widget.disabled
                ? null
                : (_) => _cancelHold(drifted: false),
            onPointerCancel: widget.disabled
                ? null
                : (_) => _cancelHold(drifted: true),
            child: Opacity(
              opacity: widget.disabled ? 0.5 : 1,
              child: Container(
                height: _height,
                width: widget.expanded ? double.infinity : null,
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(widget.radius),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x0FFFFFFF),
                      offset: Offset(0, 1),
                      blurRadius: 0,
                    ),
                    if (widget.glow && glowAlpha > 0)
                      BoxShadow(
                        color: widget.fillColor.withValues(alpha: glowAlpha * 0.7),
                        blurRadius: 32,
                        spreadRadius: -6,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      if (widget.glow && done)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: (1 - _pulse.value).clamp(0.0, 1.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(widget.radius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.fillColor.withValues(
                                        alpha: 0.55 * (1 - _pulse.value),
                                      ),
                                      blurRadius: 14 * _pulse.value,
                                      spreadRadius: 14 * _pulse.value,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Liquid fill (edge-to-edge under labels).
                      if (p > 0.001)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _HoldFillPainter(
                              progress: p,
                              fillColor: widget.fillColor,
                              wave: widget.wave,
                              waveAmplitude: widget.waveAmplitude.toDouble(),
                              direction: widget.fillDirection,
                              cycles: _cycles,
                            ),
                          ),
                        ),
                      // Idle / base label (blurs out when done).
                      Center(
                        child: Padding(
                          padding: _padding,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: done ? 0 : 1,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: done ? 2 : 0.01,
                                sigmaY: done ? 2 : 0.01,
                              ),
                              child: _labelRow(
                                color: widget.textColor,
                                done: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Done label.
                      Center(
                        child: Padding(
                          padding: _padding,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: done ? 1 : 0,
                            child: _labelRow(
                              color: done && p > 0.5
                                  ? widget.fillTextColor
                                  : widget.textColor,
                              done: true,
                            ),
                          ),
                        ),
                      ),
                      // Fill-clipped inverted label (matches React Bits ink swap).
                      if (p > 0.001 && !done)
                        Positioned.fill(
                          child: _ClippedHoldLabel(
                            progress: p,
                            direction: widget.fillDirection,
                            waveAmplitude:
                                widget.wave ? widget.waveAmplitude : 0,
                            child: Center(
                              child: Padding(
                                padding: _padding,
                                child: _labelRow(
                                  color: widget.fillTextColor,
                                  done: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _HoldPhase { idle, holding, done }

class _HoldFillPainter extends CustomPainter {
  _HoldFillPainter({
    required this.progress,
    required this.fillColor,
    required this.wave,
    required this.waveAmplitude,
    required this.direction,
    required this.cycles,
  });

  final double progress;
  final Color fillColor;
  final bool wave;
  final double waveAmplitude;
  final HoldFillDirection direction;
  final double cycles;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _fillPath(size);
    canvas.drawPath(path, Paint()..color = fillColor);
  }

  Path _fillPath(Size size) {
    final amp = wave ? waveAmplitude : 0.0;
    if (direction == HoldFillDirection.up) {
      final h = size.height * progress;
      if (amp <= 0) {
        return Path()
          ..addRect(Rect.fromLTWH(0, size.height - h, size.width, h));
      }
      final path = Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height);
      for (var x = size.width; x >= 0; x -= 1) {
        final t = x / size.width;
        final phase = -progress * cycles * 2 * math.pi;
        final oy = math.sin(t * cycles * 2 * math.pi + phase) * amp;
        path.lineTo(x, size.height - h + oy);
      }
      path.close();
      return path;
    }

    final w = size.width * progress;
    if (amp <= 0) {
      return Path()..addRect(Rect.fromLTWH(0, 0, w, size.height));
    }
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height);
    for (var y = size.height; y >= 0; y -= 1) {
      final t = y / size.height;
      final phase = -progress * cycles * 2 * math.pi;
      final ox = math.sin(t * cycles * 2 * math.pi + phase) * amp;
      path.lineTo(w + ox, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HoldFillPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.wave != wave ||
      oldDelegate.waveAmplitude != waveAmplitude ||
      oldDelegate.direction != direction;
}

/// Clips the fill-colored label so ink inverts as the fill edge crosses it.
class _ClippedHoldLabel extends StatelessWidget {
  const _ClippedHoldLabel({
    required this.progress,
    required this.direction,
    required this.waveAmplitude,
    required this.child,
  });

  final double progress;
  final HoldFillDirection direction;
  final double waveAmplitude;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HoldFillClipper(
        progress: progress,
        direction: direction,
        waveAmplitude: waveAmplitude,
      ),
      child: child,
    );
  }
}

class _HoldFillClipper extends CustomClipper<Path> {
  _HoldFillClipper({
    required this.progress,
    required this.direction,
    required this.waveAmplitude,
  });

  final double progress;
  final HoldFillDirection direction;
  final double waveAmplitude;

  @override
  Path getClip(Size size) {
    return _HoldFillPainter(
      progress: progress,
      fillColor: Colors.black,
      wave: waveAmplitude > 0,
      waveAmplitude: waveAmplitude,
      direction: direction,
      cycles: 2,
    )._fillPath(size);
  }

  @override
  bool shouldReclip(covariant _HoldFillClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.direction != direction ||
      oldClipper.waveAmplitude != waveAmplitude;
}

/// Bottom sheet: title + hold-to-confirm (returns `true` when confirmed).
Future<bool> showHoldToDeleteSheet(
  BuildContext context, {
  required String title,
  String? message,
  String holdLabel = 'Hold to delete',
  String doneLabel = 'Deleted',
  String cancelLabel = 'Cancel',
  Duration holdTime = const Duration(milliseconds: 2000),
  Widget? icon,
  Widget? doneIcon,
}) async {
  final result = await showAppModalBottomSheet<bool>(
    context: context,
    backgroundColor: HpColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
              ),
              if (message != null && message.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: HpColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              HoldButton(
                expanded: true,
                label: holdLabel,
                doneLabel: doneLabel,
                icon: icon,
                doneIcon: doneIcon,
                holdTime: holdTime,
                // Destructive red for delete / discard confirms.
                fillColor: const Color(0xFFEF4444),
                backgroundColor: const Color(0xFF27272A),
                textColor: const Color(0xFFF5F5F5),
                fillTextColor: Colors.white,
                resetAfter: Duration.zero,
                onHold: () {
                  // Let the done label + confirm haptic land before closing.
                  Future<void>.delayed(const Duration(milliseconds: 620), () {
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, false)),
                child: Text(
                  cancelLabel,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: HpColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}
