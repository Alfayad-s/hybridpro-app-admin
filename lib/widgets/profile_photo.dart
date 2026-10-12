import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';

/// Circular profile photo with letter fallback. Tap opens a fullscreen viewer.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({
    super.key,
    this.imageUrl,
    required this.letter,
    this.size = 72,
    this.heroTag,
    this.borderWidth = 1.5,
    this.allowFullscreenWithoutImage = false,
  });

  final String? imageUrl;
  final String letter;
  final double size;
  final Object? heroTag;
  final double borderWidth;
  final bool allowFullscreenWithoutImage;

  bool get _hasImage {
    final url = imageUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  void _openFullscreen(BuildContext context) {
    AppHaptics.tap();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullscreenProfilePhoto(
              imageUrl: imageUrl,
              letter: letter,
              heroTag: heroTag,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = _hasImage || allowFullscreenWithoutImage;
    Widget avatar = _AvatarCircle(
      imageUrl: imageUrl,
      letter: letter,
      size: size,
      borderWidth: borderWidth,
    );

    if (heroTag != null) {
      avatar = Hero(
        tag: heroTag!,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        child: Material(
          type: MaterialType.transparency,
          child: avatar,
        ),
      );
    }

    if (!canOpen) return avatar;

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: avatar,
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.imageUrl,
    required this.letter,
    required this.size,
    required this.borderWidth,
  });

  final String? imageUrl;
  final String letter;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HpColors.subtle,
        border: Border.all(color: HpColors.border, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _LetterFallback(letter: letter, size: size),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: HpColors.subtle,
                  child: Center(
                    child: SizedBox(
                      width: size * 0.28,
                      height: size * 0.28,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            )
          : _LetterFallback(letter: letter, size: size),
    );
  }
}

class _LetterFallback extends StatelessWidget {
  const _LetterFallback({required this.letter, required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HpColors.card,
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.inter(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: HpColors.primary,
          ),
        ),
      ),
    );
  }
}

class _FullscreenProfilePhoto extends StatelessWidget {
  const _FullscreenProfilePhoto({
    required this.imageUrl,
    required this.letter,
    this.heroTag,
  });

  final String? imageUrl;
  final String letter;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    Widget photo = hasImage
        ? Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _LetterFallback(letter: letter, size: 160),
          )
        : _LetterFallback(letter: letter, size: 160);

    if (heroTag != null) {
      photo = Hero(
        tag: heroTag!,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        child: Material(
          type: MaterialType.transparency,
          child: photo,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: AppHaptics.wrap(() => Navigator.pop(context)),
              ),
            ),
            Center(
              child: InteractiveViewer(
                minScale: 0.85,
                maxScale: 4,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                  ),
                  child: photo,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
                onPressed: AppHaptics.wrap(() => Navigator.pop(context)),
                icon: const Icon(Iconsax.close_circle, size: 26),
              ),
            ),
            if (hasImage)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: IgnorePointer(
                  child: Text(
                    'Pinch to zoom · Tap outside to close',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
