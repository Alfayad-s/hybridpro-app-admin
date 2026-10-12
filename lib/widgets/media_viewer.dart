import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/exercise_media.dart';
import '../core/utils/haptics.dart';

Future<void> showExerciseImageViewer(
  BuildContext context, {
  required String imageUrl,
  String? title,
}) {
  AppHaptics.tap();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _FullscreenImageViewer(imageUrl: imageUrl, title: title),
        );
      },
    ),
  );
}

Future<void> showExerciseVideoViewer(
  BuildContext context, {
  required String videoUrl,
  String? title,
}) {
  AppHaptics.tap();
  final source = resolveExerciseVideo(videoUrl);
  if (source == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No playable video for this exercise')),
    );
    return Future.value();
  }

  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _FullscreenVideoViewer(source: source, title: title),
        );
      },
    ),
  );
}

class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({required this.imageUrl, this.title});

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
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
                    maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Iconsax.gallery_slash,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            _ViewerChrome(title: title ?? 'Image'),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoViewer extends StatelessWidget {
  const _FullscreenVideoViewer({required this.source, this.title});

  final ExerciseVideoSource source;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final isEmbed = source.embedSrc != null;
    final watchUrl = source.youtubeId != null
        ? youtubeWatchUrl(source.youtubeId!)
        : source.embedSrc ?? source.directSrc;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isEmbed
                    ? null
                    : AppHaptics.wrap(() => Navigator.pop(context)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 56, 12, 72),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.black,
                      child: isEmbed
                          ? _EmbedVideoPlayer(
                              embedSrc: source.embedSrc!,
                              isYoutube: source.kind == ExerciseVideoKind.youtube,
                            )
                          : _DirectVideoPlayer(url: source.directSrc!),
                    ),
                  ),
                ),
              ),
            ),
            _ViewerChrome(
              title: title ?? 'Video',
              openUrl: watchUrl,
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerChrome extends StatelessWidget {
  const _ViewerChrome({required this.title, this.openUrl});

  final String title;
  final String? openUrl;

  Future<void> _openExternal() async {
    final raw = openUrl?.trim();
    if (raw == null || raw.isEmpty) return;
    AppHaptics.selection();
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          if (openUrl != null && openUrl!.trim().isNotEmpty)
            IconButton(
              tooltip: 'Open externally',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
              onPressed: _openExternal,
              icon: const Icon(Iconsax.export_1, size: 22),
            ),
          IconButton(
            tooltip: 'Close',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
            ),
            onPressed: AppHaptics.wrap(() => Navigator.pop(context)),
            icon: const Icon(Iconsax.close_circle, size: 26),
          ),
        ],
      ),
    );
  }
}

class _DirectVideoPlayer extends StatefulWidget {
  const _DirectVideoPlayer({required this.url});

  final String url;

  @override
  State<_DirectVideoPlayer> createState() => _DirectVideoPlayerState();
}

class _DirectVideoPlayerState extends State<_DirectVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller
          ..setLooping(true)
          ..play();
        _controller.addListener(_onTick);
      }).catchError((Object e) {
        if (!mounted) return;
        setState(() => _error = 'Could not play video');
      });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.inter(color: Colors.white70),
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: HpColors.primary));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio == 0
              ? 16 / 9
              : _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(
            color: Colors.black38,
            child: Row(
              children: [
                IconButton(
                  onPressed: AppHaptics.wrap(() {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  }),
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: HpColors.primary,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmbedVideoPlayer extends StatefulWidget {
  const _EmbedVideoPlayer({
    required this.embedSrc,
    this.isYoutube = false,
  });

  final String embedSrc;
  final bool isYoutube;

  @override
  State<_EmbedVideoPlayer> createState() => _EmbedVideoPlayerState();
}

class _EmbedVideoPlayerState extends State<_EmbedVideoPlayer> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final src = _withPlayerParams(widget.embedSrc);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    // YouTube error 152/153: WebView must send a real HTTPS Referer.
    // youtube-nocookie + referrer meta/policy fixes Shorts & watch embeds.
    if (widget.isYoutube) {
      _controller.loadHtmlString(
        '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html, body { margin:0; padding:0; background:#000; height:100%; overflow:hidden; }
  iframe { position:absolute; inset:0; width:100%; height:100%; border:0; }
</style>
</head>
<body>
<iframe
  src="$src"
  title="YouTube video"
  referrerpolicy="strict-origin-when-cross-origin"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen"
  allowfullscreen
></iframe>
</body>
</html>
''',
        baseUrl: 'https://www.youtube-nocookie.com',
      );
    } else {
      _controller.loadRequest(Uri.parse(src));
    }
  }

  String _withPlayerParams(String embedSrc) {
    try {
      final u = Uri.parse(embedSrc);
      final q = Map<String, String>.from(u.queryParameters);
      q.putIfAbsent('playsinline', () => '1');
      q.putIfAbsent('rel', () => '0');
      q.putIfAbsent('modestbranding', () => '1');
      // Don't force autoplay — it often triggers embed blocks on Android WebView.
      q.remove('autoplay');
      return u.replace(queryParameters: q).toString();
    } catch (_) {
      return embedSrc;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator(color: HpColors.primary)),
          ),
      ],
    );
  }
}
