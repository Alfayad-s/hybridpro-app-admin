import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

/// Soft accents for dashboard charts.
class ChartPalette {
  static const surface = Color(0xFF1A1A1E);
  static const active = Color(0xFFA0D028);
  static const expired = Color(0xFFE8A090);
  static const soon = Color(0xFF7C9CFF);
  static const total = Color(0xFFB0A8C9);
  static const revenue = Color(0xFFA0D028);
  static const orders = Color(0xFF2EC4B6);
  static const signups = Color(0xFFFFB020);
  static const track = Color(0x14FFFFFF);
}

/// Metric card matching the member weight-tracker chrome:
/// borderless dark slab, smooth animated sparkline, bold value.
class StatChartCard extends StatelessWidget {
  const StatChartCard({
    super.key,
    required this.label,
    required this.value,
    this.series = const [],
    this.accent = ChartPalette.active,
    this.subtitle,
    this.proportion,
    this.featured = false,
    this.onTap,
  });

  final String label;
  final String value;
  final List<double> series;
  final Color accent;
  final String? subtitle;

  /// Optional 0–1 fill for status cards (share of total).
  final double? proportion;

  /// Taller chart + larger type (revenue hero).
  final bool featured;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chartH = featured ? 72.0 : 56.0;
    final valueSize = featured ? 28.0 : 22.0;
    final hasSeries = series.length >= 2;

    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        featured ? 18 : 16,
        featured ? 16 : 14,
        featured ? 18 : 16,
        featured ? 16 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: featured ? 15 : 13,
              fontWeight: FontWeight.w700,
              color: HpColors.foreground,
              letterSpacing: -0.2,
              height: 1.2,
            ),
          ),
          SizedBox(height: featured ? 14 : 12),
          if (proportion != null && !hasSeries)
            _SoftProportionBar(value: proportion!, color: accent)
          else
            SizedBox(
              height: chartH,
              width: double.infinity,
              child: SparklineChart(
                values: series,
                color: accent,
                animate: true,
              ),
            ),
          SizedBox(height: featured ? 14 : 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              color: HpColors.foreground,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: HpColors.mutedForeground,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: ChartPalette.surface,
      borderRadius: BorderRadius.circular(featured ? 28 : 24),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(featured ? 28 : 24),
              child: body,
            ),
    );
  }
}

class _SoftProportionBar extends StatelessWidget {
  const _SoftProportionBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: ChartPalette.track),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: clamped,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.55),
                          color.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(clamped * 100).round()}% of clients',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: HpColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Smooth Catmull-Rom sparkline with draw-on animation (member weight style).
class SparklineChart extends StatefulWidget {
  const SparklineChart({
    super.key,
    required this.values,
    required this.color,
    this.strokeWidth = 2.6,
    this.animate = true,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool animate;

  @override
  State<SparklineChart> createState() => _SparklineChartState();
}

class _SparklineChartState extends State<SparklineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.animate) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant SparklineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listEquals(oldWidget.values, widget.values)) {
      if (widget.animate) {
        _ctrl
          ..value = 0
          ..forward();
      } else {
        _ctrl.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.values.length >= 2
        ? widget.values
        : const <double>[0, 0, 0, 0];
    final muted = widget.values.length < 2;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _SmoothSparklinePainter(
            values: series,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            muted: muted,
            progress: Curves.easeOutCubic.transform(_ctrl.value),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _SmoothSparklinePainter extends CustomPainter {
  _SmoothSparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
    required this.progress,
    this.muted = false,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;
  final double progress;
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || progress <= 0 || size.width <= 0) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 0.05 ? 1.0 : maxV - minV;
    final padY = size.height * 0.12;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * (i / (values.length - 1)),
          padY +
              (size.height - padY * 2) * (1 - ((values[i] - minV) / span)),
        ),
    ];

    final fullPath = _smoothPath(points);
    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLen = metrics.fold<double>(0, (s, m) => s + m.length);
    final drawLen = totalLen * progress.clamp(0.0, 1.0);

    final drawn = Path();
    var remaining = drawLen;
    Offset? tip;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final take = math.min(remaining, metric.length);
      drawn.addPath(metric.extractPath(0, take), Offset.zero);
      tip = metric.getTangentForOffset(take)?.position;
      remaining -= take;
    }

    final lineColor = muted ? color.withValues(alpha: 0.35) : color;

    if (tip != null && drawn.computeMetrics().isNotEmpty) {
      final fill = Path.from(drawn)
        ..lineTo(tip.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: muted ? 0.12 : 0.32),
              lineColor.withValues(alpha: 0.0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (tip != null && progress > 0.05 && !muted) {
      canvas.drawCircle(tip, 4, Paint()..color = lineColor);
      canvas.drawCircle(
        tip,
        4,
        Paint()
          ..color = ChartPalette.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SmoothSparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.muted != muted ||
      oldDelegate.progress != progress;
}

/// Horizontal soft mix bar from real segment counts.
class MixBarChart extends StatelessWidget {
  const MixBarChart({
    super.key,
    required this.title,
    required this.segments,
  });

  final String title;
  final List<({String label, int value, Color color})> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);
    final safeTotal = total <= 0 ? 1 : total;

    return Material(
      color: ChartPalette.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HpColors.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final s in segments)
                      if (s.value > 0)
                        Expanded(
                          flex: s.value,
                          child: ColoredBox(
                            color: s.color.withValues(alpha: 0.75),
                          ),
                        ),
                    if (total == 0)
                      const Expanded(
                        child: ColoredBox(color: ChartPalette.track),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final s in segments)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${s.label} ${s.value} · ${((s.value / safeTotal) * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: HpColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<double> asChartSeries(List<int> values) {
  if (values.isEmpty) return const [0, 0];
  return values.map((e) => e.toDouble()).toList();
}
