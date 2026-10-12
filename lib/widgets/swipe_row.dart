import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// One action revealed behind a [SwipeRow].
class SwipeAction {
  const SwipeAction({
    required this.id,
    required this.label,
    this.icon,
    this.color,
    this.dismiss = true,
  });

  final String id;
  final String label;
  final Widget? icon;
  final Color? color;
  final bool dismiss;
}

/// Flutter port of [React Bits SwipeRow](https://reactbits.dev/micro/swipe-row).
class SwipeRow extends StatefulWidget {
  const SwipeRow({
    super.key,
    required this.child,
    this.actions = const [
      SwipeAction(id: 'delete', label: 'Delete'),
    ],
    this.actionColor = const Color(0xFFE5484D),
    this.drawerColor = const Color(0xFF3F3F46),
    this.rowColor = const Color(0xFF27272A),
    this.textColor = const Color(0xFFF5F5F5),
    this.height = 64,
    this.radius = 16,
    this.actionWidth = 80,
    this.direction = AxisDirection.left,
    this.snapBounce = 0.2,
    this.resistance = 0.55,
    this.collapseMs = const Duration(milliseconds: 200),
    this.commitAt = 0.6,
    this.fullSwipe = true,
    this.disabled = false,
    this.haptic = true,
    this.onAction,
    this.onCommit,
    this.oppositeActions = const [],
    this.onOpposite,
    this.oppositeColor = const Color(0xFF3B82F6),
    this.margin = EdgeInsets.zero,
    this.autoHint = false,
    this.hintLabel = 'Swipe to add',
    this.oppositeHintLabel = 'Swipe to edit',
    this.sizeToChild = false,
  });

  final Widget child;
  final List<SwipeAction> actions;
  final Color actionColor;
  final Color drawerColor;
  final Color rowColor;
  final Color textColor;
  final double height;
  final double radius;
  final double actionWidth;
  final AxisDirection direction;
  final double snapBounce;
  final double resistance;
  final Duration collapseMs;
  final double commitAt;
  final bool fullSwipe;
  final bool disabled;
  final bool haptic;
  final ValueChanged<SwipeAction>? onAction;
  final ValueChanged<SwipeAction>? onCommit;

  /// Revealed by swiping the other way. A full swipe calls [onOpposite]
  /// and the row springs back, so the item stays in the list.
  final List<SwipeAction> oppositeActions;
  final ValueChanged<SwipeAction>? onOpposite;
  final Color oppositeColor;
  final EdgeInsetsGeometry margin;

  /// Plays a small open/close peek once after mount so users discover swipe.
  final bool autoHint;
  final String hintLabel;
  final String oppositeHintLabel;

  /// Size the row to [child] instead of the fixed [height].
  /// Library cards are taller than the picker rows.
  final bool sizeToChild;

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

enum _SwipePhase { idle, committing, collapsing }

class _SwipeRowState extends State<SwipeRow> with TickerProviderStateMixin {
  static const _hyst = 6.0;
  static const _flick = 90.0;

  late final AnimationController _slide;
  late final AnimationController _spread;
  late final AnimationController _collapse;

  var _phase = _SwipePhase.idle;
  var _open = false;
  var _opposite = false;
  var _dragging = false;
  var _hinting = false;
  var _hintOpposite = false;
  var _hintPlayed = false;
  double? _grab;
  double _width = 0;
  final _hist = <(int, double)>[];
  Offset? _down;
  late final AnimationController _hintHand;

  bool get _left => widget.direction == AxisDirection.left;
  double get _sign => _left ? -1 : 1;
  double get _activeSign => _opposite ? -_sign : _sign;
  double get _drawer =>
      (widget.actions.length * widget.actionWidth).clamp(0, double.infinity);
  double get _oppositeDrawer =>
      (widget.oppositeActions.length * widget.actionWidth)
          .clamp(0, double.infinity);
  double get _activeDrawer => _opposite ? _oppositeDrawer : _drawer;
  SwipeAction? get _primary =>
      widget.actions.isEmpty ? null : widget.actions.first;
  SwipeAction? get _oppositePrimary => widget.oppositeActions.isEmpty
      ? null
      : widget.oppositeActions.first;

  double get _primaryExposed {
    final raw = _slide.value;
    final exposed = _left ? -raw : raw;
    return exposed < 0 ? 0 : exposed;
  }

  double get _oppositeExposed {
    final raw = _slide.value;
    final exposed = _left ? raw : -raw;
    return exposed < 0 ? 0 : exposed;
  }

  double get _exposed => _opposite ? _oppositeExposed : _primaryExposed;

  double get _commitPoint {
    final w = math.max(_width, 1.0);
    return math.max(widget.commitAt * w, _drawer + widget.actionWidth / 2);
  }

  bool get _canCommit =>
      widget.fullSwipe && widget.actions.isNotEmpty && _commitPoint <= _width;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController.unbounded(vsync: this)..addListener(_tick);
    _spread = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_tick);
    _collapse = AnimationController(
      vsync: this,
      duration: widget.collapseMs,
    )..addListener(_tick);
    _hintHand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_tick);

    if (widget.autoHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_playHint());
      });
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _spread.dispose();
    _collapse.dispose();
    _hintHand.dispose();
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  /// Short peek that reveals the action, then snaps shut.
  Future<void> _playHint() async {
    if (_hintPlayed || widget.disabled || widget.actions.isEmpty) return;
    if (_phase != _SwipePhase.idle) return;
    // Wait a beat after the sheet settles.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted || _phase != _SwipePhase.idle || _dragging) return;
    // Ensure layout width is known.
    for (var i = 0; i < 6 && _width < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
    }
    if (_width < 8) return;

    _hintPlayed = true;
    setState(() => _hinting = true);
    if (widget.haptic) HapticFeedback.selectionClick();
    unawaited(_hintHand.forward(from: 0));

    final peek = math.min(_drawer * 0.92, widget.actionWidth * 0.95);
    await _slide.animateTo(
      _sign * peek,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || _phase != _SwipePhase.idle || _dragging) {
      setState(() => _hinting = false);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted || _phase != _SwipePhase.idle || _dragging) {
      setState(() => _hinting = false);
      return;
    }
    if (widget.haptic) HapticFeedback.lightImpact();
    await _slide.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted || _phase != _SwipePhase.idle || _dragging) {
      if (mounted) setState(() => _hinting = false);
      return;
    }
    if (widget.oppositeActions.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted || _phase != _SwipePhase.idle || _dragging) {
        if (mounted) setState(() => _hinting = false);
        return;
      }
      setState(() => _hintOpposite = true);
      _hintHand.forward(from: 0);
      final other = math.min(
        _oppositeDrawer * 0.92,
        widget.actionWidth * 0.95,
      );
      await _slide.animateTo(
        -_sign * other,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      if (!mounted || _phase != _SwipePhase.idle || _dragging) {
        if (mounted) {
          setState(() {
            _hinting = false;
            _hintOpposite = false;
          });
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!mounted || _phase != _SwipePhase.idle || _dragging) {
        if (mounted) {
          setState(() {
            _hinting = false;
            _hintOpposite = false;
          });
        }
        return;
      }
      await _slide.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) return;
    setState(() {
      _hinting = false;
      _hintOpposite = false;
    });
    _hintHand.value = 0;
  }

  double _rubber(double o, double dim, double c) {
    if (o <= 0) return 0;
    return (o * dim * c) / (dim + c * o);
  }

  double _map(double raw) {
    final d = _drawer;
    if (raw <= d) return raw.clamp(0.0, d);
    if (!_canCommit) {
      return d + _rubber(raw - d, math.max(_width - d, 1), widget.resistance);
    }
    return raw.clamp(0.0, _width);
  }

  double _mapOpposite(double raw) {
    final d = _oppositeDrawer;
    if (raw <= 0) return 0;
    if (raw <= d) return raw;
    if (!widget.fullSwipe) {
      return d + _rubber(raw - d, math.max(_width - d, 1), widget.resistance);
    }
    return raw.clamp(0.0, _width);
  }

  double get _oppositeCommitPoint {
    final w = math.max(_width, 1.0);
    return math.max(
      widget.commitAt * w,
      _oppositeDrawer + widget.actionWidth / 2,
    );
  }

  bool get _canOppositeCommit =>
      widget.fullSwipe &&
      widget.oppositeActions.isNotEmpty &&
      _oppositeCommitPoint <= _width;

  double _velocity() {
    if (_hist.length < 2) return 0;
    final a = _hist.first;
    final b = _hist.last;
    return ((b.$2 - a.$2) / math.max(1, b.$1 - a.$1)) * 1000;
  }

  void _settle(double targetExposed, {double v = 0}) {
    final target = _activeSign * targetExposed;
    final start = _slide.value;
    // Spring settle for a smoother, physical feel.
    final spring = SpringDescription(
      mass: 0.85,
      stiffness: 210,
      damping: 22,
    );
    final vel = (_activeSign * v.clamp(-1800.0, 1800.0)) / 1200.0;
    _slide.animateWith(
      SpringSimulation(spring, start, target, vel),
    );
  }

  void _setSpread(bool on) {
    if ((_spread.value >= 0.99) == on) return;
    unawaited(_spread.animateTo(on ? 1 : 0, curve: Curves.easeOutCubic));
    if (on && widget.haptic) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _commit(SwipeAction action, {double v = 0}) async {
    if (_phase != _SwipePhase.idle) return;
    setState(() => _phase = _SwipePhase.committing);
    widget.onAction?.call(action);
    if (widget.haptic) HapticFeedback.mediumImpact();

    final leap = action == _primary;
    if (leap) {
      unawaited(_spread.animateTo(1, curve: Curves.easeOutCubic));
    }
    // Notify while the row is still laid out so parents can measure thumbs.
    widget.onCommit?.call(action);

    await _slide.animateTo(
      _sign * _width,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;

    setState(() => _phase = _SwipePhase.collapsing);
    _collapse.duration = const Duration(milliseconds: 280);
    await _collapse.forward(from: 0);
  }

  /// Full swipe the other way. The row springs shut and stays in the list.
  Future<void> _commitOpposite(SwipeAction action) async {
    if (_phase != _SwipePhase.idle) return;
    setState(() => _phase = _SwipePhase.committing);
    if (widget.haptic) HapticFeedback.mediumImpact();

    await _slide.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() {
      _phase = _SwipePhase.idle;
      _opposite = false;
      _open = false;
    });
    widget.onOpposite?.call(action);
  }

  void _onDown(DragDownDetails d) {
    if (widget.disabled || widget.actions.isEmpty || _phase != _SwipePhase.idle) {
      return;
    }
    // User took over — cancel any tutorial peek.
    if (_hinting) {
      _hinting = false;
      _hintHand.stop();
      _hintHand.value = 0;
    }
    _slide.stop();
    _down = d.globalPosition;
    _grab = null;
    _dragging = false;
    _hist.clear();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (widget.disabled || _phase != _SwipePhase.idle || _down == null) return;
    final dx = d.globalPosition.dx - _down!.dx;
    final dy = d.globalPosition.dy - _down!.dy;

    if (_grab == null) {
      if (dx.abs() < _hyst || dx.abs() < dy.abs()) return;
      final movingPrimary = _left ? dx < 0 : dx > 0;
      _opposite = widget.oppositeActions.isNotEmpty && !movingPrimary;
      final sign = _activeSign;
      _grab = _exposed - sign * (dx - dx.sign * _hyst);
      _dragging = true;
    }

    final raw = _activeSign * (d.globalPosition.dx - _down!.dx) + (_grab ?? 0);
    final ex = _opposite ? _mapOpposite(raw) : _map(raw);
    // Light exponential smoothing so the row follows the finger fluidly.
    final current = _exposed;
    final smoothed = current + (ex - current) * 0.72;
    _slide.value = _activeSign * smoothed;
    final now = DateTime.now().millisecondsSinceEpoch;
    _hist.add((now, smoothed));
    if (_hist.length > 6) _hist.removeAt(0);
    if (_opposite) {
      _setSpread(_canOppositeCommit && smoothed >= _oppositeCommitPoint);
    } else {
      _setSpread(_canCommit && smoothed >= _commitPoint);
    }
  }

  void _onEnd(DragEndDetails d) {
    if (!_dragging || _phase != _SwipePhase.idle) {
      _down = null;
      _grab = null;
      _dragging = false;
      return;
    }
    final ex = _exposed;
    final pixelV = d.primaryVelocity ?? 0;
    final v = pixelV.abs() > 1 ? -_sign * pixelV : _velocity();
    _down = null;
    _grab = null;
    _dragging = false;

    if (_opposite) {
      if (_oppositePrimary != null &&
          _canOppositeCommit &&
          ex >= _oppositeCommitPoint) {
        unawaited(_commitOpposite(_oppositePrimary!));
        return;
      }
      final target = v.abs() >= _flick
          ? (v > 0 ? _oppositeDrawer : 0.0)
          : (ex > _oppositeDrawer / 2 ? _oppositeDrawer : 0.0);
      _setSpread(false);
      _open = target == _oppositeDrawer;
      if (!_open) _opposite = false;
      _settle(target, v: v);
      return;
    }

    if (_primary != null && _canCommit && ex >= _commitPoint) {
      unawaited(_commit(_primary!, v: v));
      return;
    }

    final target = v.abs() >= _flick
        ? (v > 0 ? _drawer : 0.0)
        : (ex > _drawer / 2 ? _drawer : 0.0);
    _setSpread(false);
    _open = target == _drawer;
    _settle(target, v: v);
  }

  void _onCancel() {
    _down = null;
    _grab = null;
    _dragging = false;
    if (_phase == _SwipePhase.idle) {
      _setSpread(false);
      _settle(_open ? _activeDrawer : 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collapseT = _collapse.value.clamp(0.0, 1.0);
    final h = widget.height * (1 - collapseT);
    final opacity = 1 - collapseT;
    final mb = (widget.margin is EdgeInsets)
        ? (widget.margin as EdgeInsets).bottom * (1 - collapseT)
        : 8.0 * (1 - collapseT);

    return Opacity(
      opacity: widget.disabled ? 0.55 : opacity,
      child: widget.sizeToChild
          ? ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: (1 - collapseT).clamp(0.0, 1.0),
                child: _swipeBody(mb),
              ),
            )
          : SizedBox(
              height: math.max(0, h),
              child: _swipeBody(mb),
            ),
    );
  }

  Widget _swipeBody(double bottomMargin) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          final spread = _spread.value.clamp(0.0, 1.0);
          final slide = _slide.value;
          final primary = _primary;
          final actionFill = primary?.color ?? widget.actionColor;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.radius),
                child: Stack(
                  fit: widget.sizeToChild
                      ? StackFit.passthrough
                      : StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: widget.drawerColor),
                    ),
                        // Full-swipe commit block (grows under primary)
                        if (primary != null)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: _left ? 0 : null,
                            left: _left ? null : 0,
                            width: widget.actionWidth +
                                (_canCommit
                                    ? math.max(0, _primaryExposed - _drawer) *
                                            (spread > 0 && !_opposite ? 1 : 0)
                                                .toDouble()
                                                .clamp(0, 1) +
                                        (_width - widget.actionWidth) *
                                            (spread > 0 && !_opposite
                                                ? spread
                                                : 0)
                                    : 0),
                            child: ColoredBox(color: actionFill),
                          ),
                        if (_oppositePrimary != null)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: _left ? 0 : null,
                            right: _left ? null : 0,
                            width: widget.actionWidth +
                                (widget.fullSwipe
                                    ? math.max(0, _oppositeExposed - _oppositeDrawer) *
                                            (spread > 0 && _opposite ? 1 : 0) +
                                        (_width - widget.actionWidth) *
                                            (spread > 0 && _opposite ? spread : 0)
                                    : 0),
                            child: ColoredBox(color: widget.oppositeColor),
                          ),
                        // Action buttons
                        for (var i = 0; i < widget.actions.length; i++)
                          _buildAction(i, spread),
                        for (var i = 0; i < widget.oppositeActions.length; i++)
                          _buildOppositeAction(i, spread),
                        // Foreground row. The drag detector lives inside the
                        // translate so its hit box moves with the card. If it
                        // wraps the translate, the unshifted full-width box
                        // stays on top and swallows taps on Edit / Delete.
                        Transform.translate(
                          offset: Offset(slide, 0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragDown: _onDown,
                            onHorizontalDragUpdate: _onUpdate,
                            onHorizontalDragEnd: _onEnd,
                            onHorizontalDragCancel: _onCancel,
                            onTap: _open && _phase == _SwipePhase.idle
                                ? () {
                                    _open = false;
                                    _settle(0);
                                  }
                                : null,
                            child: Container(
                              color: widget.rowColor,
                              alignment: Alignment.centerLeft,
                              child: DefaultTextStyle(
                                style: GoogleFonts.inter(
                                  color: widget.textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hinting) _buildHintOverlay(peekProgress: _exposed / math.max(_drawer, 1)),
                ],
              );
            },
          ),
    );
  }

  Widget _buildHintOverlay({required double peekProgress}) {
    final t = _hintHand.value.clamp(0.0, 1.0);
    final showLeftSwipe = _hintOpposite ? !_left : _left;
    final accent = _hintOpposite ? widget.oppositeColor : widget.actionColor;
    // Hand drifts with the peek.
    final handX = 28.0 - 36.0 * Curves.easeOutCubic.transform(t.clamp(0.0, 0.7) / 0.7);
    final fade = t < 0.12
        ? t / 0.12
        : (t > 0.85 ? (1 - t) / 0.15 : 1.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Stack(
            children: [
              // Soft spotlight on the row.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              // Drag finger cue.
              Positioned(
                right: showLeftSwipe ? 18 + handX : null,
                left: showLeftSwipe ? null : 18 + handX,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              showLeftSwipe
                                  ? Icons.swipe_left_rounded
                                  : Icons.swipe_right_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _hintOpposite
                                  ? widget.oppositeHintLabel
                                  : widget.hintLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Transform.translate(
                        offset: Offset(
                          showLeftSwipe ? -handX * 0.35 : handX * 0.35,
                          0,
                        ),
                        child: Icon(
                          Icons.touch_app_rounded,
                          size: 22,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction(int i, double spread) {
    final a = widget.actions[i];
    final isPrimary = i == 0;
    final color = a.color ??
        (isPrimary && spread > 0.5 ? widget.actionColor : widget.drawerColor);
    final onColor = _onColor(color);
    final left = _left
        ? null
        : (i * widget.actionWidth).toDouble();
    final right = _left
        ? (i * widget.actionWidth).toDouble()
        : null;

    return Positioned(
      top: 0,
      bottom: 0,
      left: left,
      right: right,
      width: widget.actionWidth +
          (isPrimary && _canCommit ? (_width - widget.actionWidth) * spread : 0),
      child: Material(
        color: isPrimary && spread > 0.15 ? widget.actionColor : color,
        child: InkWell(
          onTap: () {
            if (a.dismiss) {
              unawaited(_commit(a));
              return;
            }
            widget.onAction?.call(a);
            if (_phase != _SwipePhase.idle) return;
            _open = false;
            _settle(0);
          },
          child: Center(
            child: Opacity(
              opacity: isPrimary && spread > 0.4
                  ? 1
                  : (1 - spread * (isPrimary ? 0.2 : 0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (a.icon != null)
                    IconTheme(
                      data: IconThemeData(color: onColor, size: 20),
                      child: a.icon!,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    a.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: onColor,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOppositeAction(int i, double spread) {
    final a = widget.oppositeActions[i];
    final isPrimary = i == 0;
    final onColor = _onColor(widget.oppositeColor);
    final grow = isPrimary && widget.fullSwipe && _opposite
        ? (_width - widget.actionWidth) * spread
        : 0.0;

    return Positioned(
      top: 0,
      bottom: 0,
      left: _left ? (i * widget.actionWidth).toDouble() : null,
      right: _left ? null : (i * widget.actionWidth).toDouble(),
      width: widget.actionWidth + grow,
      child: Material(
        color: widget.oppositeColor,
        child: InkWell(
          onTap: () => unawaited(_commitOpposite(a)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (a.icon != null)
                  IconTheme(
                    data: IconThemeData(color: onColor, size: 20),
                    child: a.icon!,
                  ),
                const SizedBox(height: 4),
                Text(
                  a.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onColor,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _onColor(Color bg) {
    return bg.computeLuminance() >= 0.55
        ? const Color(0xFF111111)
        : Colors.white;
  }
}
