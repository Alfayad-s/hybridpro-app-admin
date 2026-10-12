import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';

class RubberSegmentItem {
  const RubberSegmentItem({required this.value, required this.label});

  final String value;
  final String label;
}

enum RubberSegmentSize { sm, md, lg }

/// Flutter port of [React Bits Rubber Segment](https://reactbits.dev/micro/rubber-segment).
///
/// Left/right edge positions are stored as fractions of the inner track width
/// so layout never stretches the thumb across the whole bar.
class RubberSegment extends StatefulWidget {
  const RubberSegment({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.trackColor = const Color(0xFF1C1C22),
    this.thumbColor = HpColors.primary,
    this.textColor = const Color(0xB3FFFFFF),
    this.activeTextColor = HpColors.primaryForeground,
    this.size = RubberSegmentSize.md,
    this.radius = 12,
    this.inset = 3,
    this.stretch = 100,
    this.squash = 3,
    this.speed = 1,
    this.glide = 75,
    this.draggable = true,
    this.disabled = false,
  });

  final List<RubberSegmentItem> items;
  final String value;
  final ValueChanged<String> onChanged;
  final Color trackColor;
  final Color thumbColor;
  final Color textColor;
  final Color activeTextColor;
  final RubberSegmentSize size;
  final double radius;
  final double inset;
  final double stretch;
  final double squash;
  final double speed;
  final double glide;
  final bool draggable;
  final bool disabled;

  @override
  State<RubberSegment> createState() => _RubberSegmentState();
}

class _RubberSegmentState extends State<RubberSegment>
    with TickerProviderStateMixin {
  static const _easeOut = Cubic(0.23, 1, 0.32, 1);
  static const _dilateSec = 0.19;
  static const _handoffSec = 0.15;
  static const _flickVx = 110.0;
  static const _maxVx = 2000.0;
  static const _deadzone = 4.0;
  static const _rubber = 0.55;

  /// Edge positions as fractions of inner width (0..1).
  late final AnimationController _l;
  late final AnimationController _r;

  final _hist = <(int, double)>[];
  Timer? _handoff;
  int _gen = 0;
  int _committed = 0;

  /// Latest measured inner width (px). Used only for pointer math / squash.
  double _innerW = 0;

  bool _dragging = false;
  bool _dragLive = false;
  bool _onThumb = false;
  double _x0 = 0;
  double _dragOffset = 0;
  double _dragW = 0;
  int _pressSlot = -1;

  ({double h, double font}) get _preset => switch (widget.size) {
        RubberSegmentSize.sm => (h: 32.0, font: 12.0),
        RubberSegmentSize.md => (h: 40.0, font: 13.0),
        RubberSegmentSize.lg => (h: 48.0, font: 14.0),
      };

  int get _index {
    final i = widget.items.indexWhere((e) => e.value == widget.value);
    return i < 0 ? 0 : i;
  }

  int get _count => widget.items.length;

  (double, double) _slotFrac(int i) {
    if (_count <= 0) return (0, 1);
    final n = _count.toDouble();
    return (i / n, (i + 1) / n);
  }

  double _t(double s) => s / widget.speed.clamp(0.05, 8);

  double _rubberBand(double over, double dim) =>
      (over * dim * _rubber) / (dim + _rubber * over.abs());

  double _project(double v) {
    final d = 1 - 0.1 * math.pow(0.05, widget.glide / 100);
    return ((v / 1000) * d) / (1 - d);
  }

  double _velocity() {
    if (_hist.length < 2) return 0;
    final now = _hist.last.$1;
    final recent = _hist.where((e) => now - e.$1 <= 100).toList();
    if (recent.length < 2) return 0;
    final a = recent.first;
    final b = recent.last;
    final dt = b.$1 - a.$1;
    return dt >= 8 ? ((b.$2 - a.$2) / dt) * 1000 : 0;
  }

  int _nearestPx(double x) {
    if (_innerW <= 0 || _count <= 0) return 0;
    final slotW = _innerW / _count;
    var best = 0;
    for (var i = 1; i < _count; i++) {
      final mid = (i + 0.5) * slotW;
      final bestMid = (best + 0.5) * slotW;
      if ((mid - x).abs() < (bestMid - x).abs()) best = i;
    }
    return best;
  }

  int _slotAtPx(double x) {
    if (_innerW <= 0 || _count <= 0) return 0;
    return (x / (_innerW / _count)).floor().clamp(0, _count - 1);
  }

  void _snapTo(int i) {
    final e = _slotFrac(i.clamp(0, math.max(0, _count - 1)));
    _l.value = e.$1;
    _r.value = e.$2;
  }

  @override
  void initState() {
    super.initState();
    _l = AnimationController.unbounded(vsync: this);
    _r = AnimationController.unbounded(vsync: this);
    _committed = _index;
    _snapTo(_committed);
  }

  @override
  void didUpdateWidget(covariant RubberSegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _snapTo(_index);
      _committed = _index;
      return;
    }
    if (!_dragging && _committed != _index) {
      _committed = _index;
      _snapTo(_index);
    }
  }

  @override
  void dispose() {
    _handoff?.cancel();
    _gen++;
    _l.stop();
    _r.stop();
    _l.dispose();
    _r.dispose();
    super.dispose();
  }

  void _commit(int i) {
    if (i < 0 || i >= _count) return;
    _committed = i;
    final next = widget.items[i].value;
    if (next == widget.value) return;
    AppHaptics.selection();
    widget.onChanged(next);
  }

  Future<void> _spring(
    AnimationController c,
    double to, {
    required double duration,
    double velocity = 0,
  }) {
    if (!mounted) return Future.value();
    c.stop();
    final spring = SpringDescription(
      mass: 1,
      stiffness: duration < 0.2 ? 420 : (duration > 0.35 ? 200 : 280),
      damping: duration < 0.2 ? 28 : 22,
    );
    return c.animateWith(
      SpringSimulation(spring, c.value, to, velocity / 1000),
    );
  }

  Future<void> _tween(
    AnimationController c,
    double to, {
    required double duration,
  }) {
    if (!mounted) return Future.value();
    c.stop();
    return c.animateTo(
      to,
      duration: Duration(
        milliseconds: math.max(1, (_t(duration) * 1000).round()),
      ),
      curve: _easeOut,
    );
  }

  void _land(
    int to, {
    double velocity = 0,
    required bool flick,
    required bool withSquash,
  }) {
    if (!mounted || to < 0 || to >= _count || _innerW <= 0) return;
    final e = _slotFrac(to);
    final g = ++_gen;
    final mid = (_l.value + _r.value) / 2;
    var dir = ((e.$1 + e.$2) / 2 - mid).sign;
    if (dir == 0) dir = 1;

    final lead = dir > 0 ? _r : _l;
    final trail = dir > 0 ? _l : _r;
    final leadTo = dir > 0 ? e.$2 : e.$1;
    final trailTo = dir > 0 ? e.$1 : e.$2;
    // Controllers store fractions; convert px/s → fraction/s.
    final v = (velocity.clamp(-_maxVx, _maxVx)) / _innerW;
    final squashF = widget.squash / _innerW;

    _spring(lead, leadTo, duration: flick ? 0.4 : 0.3, velocity: v);

    if (!withSquash || widget.squash <= 0) {
      _spring(trail, trailTo, duration: 0.3, velocity: v);
      return;
    }

    _spring(
      trail,
      trailTo + dir * squashF,
      duration: 0.3,
      velocity: v,
    ).then((_) {
      if (!mounted || _gen != g) return;
      _spring(trail, trailTo, duration: 0.16);
    });
  }

  void _travel(int from, int to) {
    if (!mounted || from == to || from < 0 || to < 0) return;
    if (from >= _count || to >= _count) return;

    final a = _slotFrac(from);
    final b = _slotFrac(to);
    _handoff?.cancel();
    _gen++;

    if (MediaQuery.disableAnimationsOf(context)) {
      _snapTo(to);
      return;
    }

    final u = (widget.stretch / 100).clamp(0.0, 1.0);
    final dilateL = b.$1 + (math.min(a.$1, b.$1) - b.$1) * u;
    final dilateR = b.$2 + (math.max(a.$2, b.$2) - b.$2) * u;

    _tween(_l, dilateL, duration: _dilateSec);
    _tween(_r, dilateR, duration: _dilateSec);

    _handoff = Timer(
      Duration(milliseconds: math.max(1, (_t(_handoffSec) * 1000).round())),
      () {
        if (!mounted) return;
        _land(to, flick: false, withSquash: true);
      },
    );
  }

  void _down(double x) {
    if (widget.disabled || _innerW <= 0) return;
    _dragging = true;
    _dragLive = false;
    _x0 = x;
    _pressSlot = _slotAtPx(x);
    final leftPx = _l.value * _innerW;
    final rightPx = _r.value * _innerW;
    _onThumb = widget.draggable && x >= leftPx && x <= rightPx;
    _hist
      ..clear()
      ..add((DateTime.now().millisecondsSinceEpoch, x));
    if (_onThumb) {
      _handoff?.cancel();
      _gen++;
      _l.stop();
      _r.stop();
    }
    setState(() {});
  }

  void _move(double x) {
    if (!_dragging || !_onThumb || _innerW <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _hist.add((now, x));
    if (_hist.length > 8) _hist.removeAt(0);

    if (!_dragLive) {
      if ((x - _x0).abs() < _deadzone) return;
      _dragLive = true;
      _dragOffset = x - _l.value * _innerW;
      _dragW = math.max(12.0, (_r.value - _l.value) * _innerW);
      setState(() {});
    }

    final maxL = _innerW - _dragW;
    final left = x - _dragOffset;

    if (left < 0) {
      _l.value = 0;
      _r.value = (_dragW - _rubberBand(-left, _dragW)) / _innerW;
    } else if (left > maxL) {
      _r.value = 1;
      _l.value = (maxL + _rubberBand(left - maxL, _dragW)) / _innerW;
    } else {
      _l.value = left / _innerW;
      _r.value = (left + _dragW) / _innerW;
    }
  }

  void _up(double x) {
    if (!_dragging) return;
    final live = _dragLive;
    final onThumb = _onThumb;
    final press = _pressSlot;
    _dragging = false;
    _dragLive = false;
    _onThumb = false;
    _pressSlot = -1;
    setState(() {});

    if (!live) {
      if ((x - _x0).abs() <= 10 && press >= 0 && press != _committed) {
        final from = _committed;
        _commit(press);
        _travel(from, press);
      }
      return;
    }
    if (!onThumb || _innerW <= 0) return;

    final v = _velocity();
    final flick = v.abs() > _flickVx;
    final midPx = ((_l.value + _r.value) / 2) * _innerW + _project(v);
    var to = _nearestPx(midPx);
    if (flick && to == _committed) {
      to = (to + v.sign.toInt()).clamp(0, _count - 1);
    }
    _commit(to);
    _land(to, velocity: v, flick: flick, withSquash: flick);
  }

  void _cancel() {
    if (!_dragging) return;
    final live = _dragLive;
    _dragging = false;
    _dragLive = false;
    _onThumb = false;
    _pressSlot = -1;
    setState(() {});
    if (live) _land(_committed, flick: false, withSquash: false);
  }

  @override
  Widget build(BuildContext context) {
    final preset = _preset;
    final thumbRadius = math.max(0.0, widget.radius - widget.inset);

    return Opacity(
      opacity: widget.disabled ? 0.5 : 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackW = constraints.maxWidth;
          final innerW = math.max(0.0, trackW - widget.inset * 2);
          _innerW = innerW;

          return SizedBox(
            height: preset.h,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.trackColor,
                borderRadius: BorderRadius.circular(widget.radius),
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.inset),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(thumbRadius),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_l, _r]),
                    builder: (context, _) {
                      final left = (_l.value * innerW).clamp(0.0, innerW);
                      final right = (_r.value * innerW).clamp(0.0, innerW);
                      final thumbW = (right - left).clamp(0.0, innerW);

                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: widget.disabled
                            ? null
                            : (e) {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                _down(box.globalToLocal(e.position).dx);
                              },
                        onPointerMove: widget.disabled
                            ? null
                            : (e) {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                _move(box.globalToLocal(e.position).dx);
                              },
                        onPointerUp: widget.disabled
                            ? null
                            : (e) {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                _up(box.globalToLocal(e.position).dx);
                              },
                        onPointerCancel:
                            widget.disabled ? null : (_) => _cancel(),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            if (innerW > 0 && thumbW > 0.5)
                              Positioned(
                                left: left,
                                width: thumbW,
                                top: 0,
                                bottom: 0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: widget.thumbColor,
                                    borderRadius:
                                        BorderRadius.circular(thumbRadius),
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                for (var i = 0; i < _count; i++)
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        widget.items[i].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: preset.font,
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                          color: i == _committed
                                              ? widget.activeTextColor
                                              : widget.textColor,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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
