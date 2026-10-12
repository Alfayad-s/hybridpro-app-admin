/// Resolve exercise video URLs (mirrors mobile `exercise-media.ts`).
enum ExerciseVideoKind { youtube, vimeo, embed, direct }

class ExerciseVideoSource {
  const ExerciseVideoSource({
    required this.kind,
    this.embedSrc,
    this.directSrc,
    this.youtubeId,
  });

  final ExerciseVideoKind kind;
  final String? embedSrc;
  final String? directSrc;
  final String? youtubeId;
}

final _directVideoPattern = RegExp(r'\.(mp4|webm|mov|m4v|ogv|m3u8)(\?|$)', caseSensitive: false);
final _youtubeIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Extract an 11-char YouTube video id from watch / shorts / embed / youtu.be links.
String? extractYoutubeId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  // Bare id pasted by mistake.
  if (_youtubeIdPattern.hasMatch(trimmed)) return trimmed;

  try {
    var parsed = Uri.parse(trimmed);
    if (!parsed.hasScheme) {
      parsed = Uri.parse('https://$trimmed');
    }
    final host = parsed.host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();

    if (host == 'youtu.be') {
      final id = parsed.pathSegments.isNotEmpty ? parsed.pathSegments.first : null;
      return _youtubeIdPattern.hasMatch(id ?? '') ? id : null;
    }

    final isYoutube = host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtube-nocookie.com';
    if (!isYoutube) return null;

    final segments = parsed.pathSegments;
    if (segments.isNotEmpty && segments.first == 'shorts' && segments.length > 1) {
      final id = segments[1];
      return _youtubeIdPattern.hasMatch(id) ? id : null;
    }
    if (segments.isNotEmpty && segments.first == 'embed' && segments.length > 1) {
      final id = segments[1];
      return _youtubeIdPattern.hasMatch(id) ? id : null;
    }
    if (segments.isNotEmpty && segments.first == 'live' && segments.length > 1) {
      final id = segments[1];
      return _youtubeIdPattern.hasMatch(id) ? id : null;
    }
    final v = parsed.queryParameters['v'];
    if (_youtubeIdPattern.hasMatch(v ?? '')) return v;
  } catch (_) {
    return null;
  }
  return null;
}

String youtubeEmbedUrl(String videoId) =>
    'https://www.youtube-nocookie.com/embed/$videoId';

String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';

String? toYoutubeEmbedUrl(String url) {
  final id = extractYoutubeId(url);
  if (id == null) return null;
  return youtubeEmbedUrl(id);
}

/// Canonical https URL to store (watch link for YouTube, otherwise original).
String? normalizeExerciseVideoUrl(String? url) {
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final id = extractYoutubeId(trimmed);
  if (id != null) return youtubeWatchUrl(id);
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)) {
    final withScheme = 'https://$trimmed';
    if (hasExerciseVideo(withScheme)) return normalizeExerciseVideoUrl(withScheme);
    return null;
  }
  return trimmed;
}

String? toVimeoEmbedUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  try {
    var u = Uri.parse(trimmed);
    if (!u.hasScheme) u = Uri.parse('https://$trimmed');
    final host = u.host.replaceFirst(RegExp(r'^www\.'), '');
    if (host == 'vimeo.com') {
      final id = u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
      if (id != null && RegExp(r'^\d+$').hasMatch(id)) {
        return 'https://player.vimeo.com/video/$id';
      }
    }
    if (host == 'player.vimeo.com' && u.path.startsWith('/video/')) {
      return trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    }
  } catch (_) {
    return null;
  }
  return null;
}

bool isDirectVideoUrl(String url) {
  if (_directVideoPattern.hasMatch(url)) return true;
  return RegExp(r'/video/upload/', caseSensitive: false).hasMatch(url);
}

ExerciseVideoSource? resolveExerciseVideo(String? url) {
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  final youtubeId = extractYoutubeId(trimmed);
  if (youtubeId != null) {
    return ExerciseVideoSource(
      kind: ExerciseVideoKind.youtube,
      embedSrc: youtubeEmbedUrl(youtubeId),
      youtubeId: youtubeId,
    );
  }

  final withScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
      ? trimmed
      : 'https://$trimmed';

  final vimeo = toVimeoEmbedUrl(withScheme);
  if (vimeo != null) {
    return ExerciseVideoSource(kind: ExerciseVideoKind.vimeo, embedSrc: vimeo);
  }

  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(withScheme)) {
    return null;
  }

  if (isDirectVideoUrl(withScheme)) {
    return ExerciseVideoSource(kind: ExerciseVideoKind.direct, directSrc: withScheme);
  }

  try {
    final u = Uri.parse(withScheme);
    if (u.path.contains('/embed/') || u.path.contains('/player/')) {
      return ExerciseVideoSource(kind: ExerciseVideoKind.embed, embedSrc: withScheme);
    }
  } catch (_) {
    return null;
  }

  return ExerciseVideoSource(kind: ExerciseVideoKind.direct, directSrc: withScheme);
}

bool hasExerciseVideo(String? url) => resolveExerciseVideo(url) != null;

bool hasExerciseImage(String? url) {
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) return false;
  final candidate = RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
      ? trimmed
      : 'https://$trimmed';
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(candidate);
}
