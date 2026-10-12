import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/exercise_media.dart';
import '../core/utils/haptics.dart';
import 'swipe_row.dart';

/// Shared page padding used across admin list screens.
class PageInsets {
  static const page = EdgeInsets.fromLTRB(16, 16, 16, 100);
  static const cardGap = 10.0;
  static const sectionGap = 16.0;
  static const chipGap = 8.0;
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusPillTone.neutral,
  });

  final String label;
  final StatusPillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusPillTone.success => (
          HpColors.primary.withValues(alpha: 0.16),
          HpColors.primary,
        ),
      StatusPillTone.warning => (
          const Color(0xFFF59E0B).withValues(alpha: 0.16),
          const Color(0xFFF59E0B),
        ),
      StatusPillTone.danger => (
          HpColors.destructive.withValues(alpha: 0.16),
          HpColors.destructive,
        ),
      StatusPillTone.neutral => (
          HpColors.subtle,
          HpColors.mutedForeground,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

enum StatusPillTone { neutral, success, warning, danger }

class AdminListCard extends StatelessWidget {
  const AdminListCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: PageInsets.cardGap),
      child: Material(
        color: HpColors.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: AppHaptics.wrap(onTap),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HpColors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Square media thumb — shows network image or a soft placeholder.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    this.imageUrl,
    this.size = 64,
    this.icon = Iconsax.gallery,
    this.label,
    this.onTap,
  });

  final String? imageUrl;
  final double size;
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    Widget child = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Placeholder(icon: icon, label: label),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _Placeholder(icon: icon, label: label, loading: true);
                },
              )
            : _Placeholder(icon: icon, label: label),
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    this.label,
    this.loading = false,
  });

  final IconData icon;
  final String? label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HpColors.subtle,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: HpColors.mutedForeground),
                  if (label != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      label!,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: HpColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Compact video slot — dashed when empty, playable when [videoUrl] is set.
class VideoThumb extends StatelessWidget {
  const VideoThumb({
    super.key,
    this.videoUrl,
    this.width = 52,
    this.height = 64,
    this.onTap,
  });

  final String? videoUrl;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasVideo = hasExerciseVideo(videoUrl);

    Widget body = CustomPaint(
      painter: _DashedBorderPainter(
        color: hasVideo ? HpColors.primary.withValues(alpha: 0.45) : HpColors.border,
        radius: 12,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: hasVideo
              ? HpColors.primary.withValues(alpha: 0.08)
              : HpColors.subtle.withValues(alpha: 0.65),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasVideo ? Iconsax.video_play : Iconsax.video,
                size: 18,
                color: hasVideo
                    ? HpColors.primary
                    : HpColors.mutedForeground.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 4),
              Text(
                hasVideo ? 'Play' : 'Video',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: hasVideo ? HpColors.primary : HpColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      ),
    );
  }
}

/// Kept for older call sites — prefer [VideoThumb].
class VideoPlaceholder extends StatelessWidget {
  const VideoPlaceholder({super.key, this.width = 52, this.height = 64});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return VideoThumb(width: width, height: height);
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashWidth: 4, dashSpace: 3);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, {required double dashWidth, required double dashSpace}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dest.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        distance = next + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class MetaText extends StatelessWidget {
  const MetaText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 12,
        height: 1.35,
        color: HpColors.mutedForeground,
      ),
    );
  }
}

class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: HpColors.foreground,
      ),
    );
  }
}

/// Library row: swipe left to delete, swipe right to edit.
class LibrarySwipeCard extends StatelessWidget {
  const LibrarySwipeCard({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.showHint = false,
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    return SwipeRow(
      sizeToChild: true,
      height: 96,
      radius: 16,
      actionWidth: 84,
      direction: AxisDirection.left,
      fullSwipe: false,
      autoHint: showHint,
      hintLabel: 'Swipe left to delete',
      oppositeHintLabel: 'Swipe right to edit',
      actionColor: const Color(0xFFE5484D),
      oppositeColor: const Color(0xFF3B82F6),
      drawerColor: const Color(0xFF3F3F46),
      rowColor: HpColors.card,
      margin: EdgeInsets.zero,
      actions: const [
        SwipeAction(
          id: 'delete',
          label: 'Delete',
          dismiss: false,
          color: Color(0xFFE5484D),
          icon: Icon(Iconsax.trash, size: 20, color: Colors.white),
        ),
      ],
      oppositeActions: const [
        SwipeAction(
          id: 'edit',
          label: 'Edit',
          icon: Icon(Iconsax.edit_2, size: 20, color: Colors.white),
        ),
      ],
      onAction: (_) => onDelete(),
      onOpposite: (_) => onEdit(),
      child: child,
    );
  }
}
