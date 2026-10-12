import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/admin_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/exercise_media.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/hold_button.dart';
import '../../../widgets/keyboard_aware_sheet.dart';
import '../../../widgets/media_viewer.dart';

const _defaultExerciseImage =
    'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=800&q=80';

Future<Map<String, dynamic>?> showExerciseEditSheet(
  BuildContext context, {
  required WidgetRef ref,
  Exercise? existing,
}) {
  return KeyboardAwareSheet.show<Map<String, dynamic>>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.88,
    builder: (ctx) => _ExerciseEditSheet(ref: ref, existing: existing),
  );
}

class _ExerciseEditSheet extends ConsumerStatefulWidget {
  const _ExerciseEditSheet({required this.ref, this.existing});

  final WidgetRef ref;
  final Exercise? existing;

  @override
  ConsumerState<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends ConsumerState<_ExerciseEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _muscle;
  late final TextEditingController _target;
  late final TextEditingController _equipment;
  late final TextEditingController _difficulty;
  late final TextEditingController _instructions;
  late final TextEditingController _imageLink;
  late final TextEditingController _videoLink;

  late String _imageUrl;
  late String _videoUrl;
  String? _uploading;
  String? _error;
  bool _saving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _muscle = TextEditingController(text: e?.muscleGroup ?? 'Chest');
    _target = TextEditingController(text: e?.target ?? '');
    _equipment = TextEditingController(text: e?.equipment ?? 'Bodyweight');
    _difficulty = TextEditingController(text: e?.difficulty ?? 'Beginner');
    _instructions = TextEditingController(text: e?.instructions.join('\n') ?? '');
    _imageUrl = (e?.imageUrl ?? '').trim();
    _videoUrl = (e?.videoUrl ?? '').trim();
    _imageLink = TextEditingController();
    _videoLink = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _muscle.dispose();
    _target.dispose();
    _equipment.dispose();
    _difficulty.dispose();
    _instructions.dispose();
    _imageLink.dispose();
    _videoLink.dispose();
    super.dispose();
  }

  String get _exerciseKey {
    final existing = widget.existing;
    String raw;
    if (existing != null) {
      raw = existing.uuid.isNotEmpty ? existing.uuid : existing.id;
    } else {
      final slug = _slug.text.trim().isNotEmpty
          ? _slug.text.trim()
          : _name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      raw = slug.isEmpty ? 'draft-${DateTime.now().millisecondsSinceEpoch}' : slug;
    }
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (clean.isEmpty) return 'draft-${DateTime.now().millisecondsSinceEpoch}';
    return clean.length > 64 ? clean.substring(0, 64) : clean;
  }

  Future<void> _pickImage() async {
    AppHaptics.selection();
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;
    await _upload(file.path, file.name, 'image');
  }

  Future<void> _pickVideo() async {
    AppHaptics.selection();
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (file == null) return;
    await _upload(file.path, file.name, 'video');
  }

  Future<void> _upload(String path, String name, String kind) async {
    setState(() {
      _uploading = kind;
      _error = null;
    });
    try {
      final url = await widget.ref.read(adminRepositoryProvider).uploadExerciseMedia(
            filePath: path,
            filename: name,
            kind: kind,
            exerciseKey: _exerciseKey,
          );
      if (!mounted) return;
      setState(() {
        if (kind == 'image') {
          _imageUrl = url;
          _imageLink.clear();
        } else {
          _videoUrl = url;
          _videoLink.clear();
        }
        _uploading = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _uploading = null;
      });
    }
  }

  void _applyImageLink() {
    AppHaptics.selection();
    final trimmed = _imageLink.text.trim();
    if (trimmed.isEmpty) return;
    if (!hasExerciseImage(trimmed)) {
      setState(() => _error = 'Enter a valid image URL (https://…)');
      return;
    }
    setState(() {
      _imageUrl = trimmed;
      _error = null;
    });
  }

  void _applyVideoLink() {
    AppHaptics.selection();
    final trimmed = _videoLink.text.trim();
    if (trimmed.isEmpty) return;
    final normalized = normalizeExerciseVideoUrl(trimmed);
    if (normalized == null || !hasExerciseVideo(normalized)) {
      setState(
        () => _error =
            'Enter a valid video URL (YouTube, Shorts, Vimeo, MP4, etc.)',
      );
      return;
    }
    setState(() {
      _videoUrl = normalized;
      _videoLink.text = normalized;
      _error = null;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    AppHaptics.tap();
    setState(() => _saving = true);
    Navigator.pop(context, {
      'name': name,
      if (_slug.text.trim().isNotEmpty) 'slug': _slug.text.trim(),
      'muscleGroup': _muscle.text.trim(),
      'target': _target.text.trim(),
      'equipment': _equipment.text.trim(),
      'difficulty': _difficulty.text.trim(),
      'instructions': _instructions.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'imageUrl': _imageUrl.trim().isEmpty ? _defaultExerciseImage : _imageUrl.trim(),
      'videoUrl': normalizeExerciseVideoUrl(_videoUrl),
    });
  }

  bool get _hasCustomImage =>
      _imageUrl.isNotEmpty && _imageUrl != _defaultExerciseImage;

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final busy = _uploading != null || _saving;
    final media = MediaQuery.of(context);

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: HpColors.mutedForeground.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  existing == null ? 'New exercise' : 'Edit exercise',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: AppHaptics.wrap(() => Navigator.pop(context)),
                icon: const Icon(Iconsax.close_circle, size: 22),
                color: HpColors.mutedForeground,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: HpColors.border),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + media.viewInsets.bottom,
            ),
            children: [
                TextField(
                  controller: _name,
                  decoration: _fieldDecoration('Name'),
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _slug,
                  decoration: _fieldDecoration('Slug', hint: 'optional'),
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _muscle,
                        decoration: _fieldDecoration('Muscle group'),
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _target,
                        decoration: _fieldDecoration('Target'),
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _equipment,
                        decoration: _fieldDecoration('Equipment'),
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _difficulty,
                        decoration: _fieldDecoration('Difficulty'),
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _instructions,
                  decoration: _fieldDecoration(
                    'Instructions',
                    hint: 'One step per line',
                  ),
                  maxLines: 3,
                  minLines: 3,
                  enabled: !busy,
                ),
                const SizedBox(height: 20),
                _SectionLabel('Photo'),
                const SizedBox(height: 8),
                _MediaBlock(
                  previewHeight: 132,
                  preview: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _imageUrl.isEmpty ? _defaultExerciseImage : _imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: HpColors.subtle,
                          child: Icon(
                            Iconsax.gallery,
                            color: HpColors.mutedForeground,
                          ),
                        ),
                      ),
                      if (_uploading == 'image')
                        const ColoredBox(
                          color: Color(0x990B0B0F),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                  primaryAction: FilledButton.icon(
                    onPressed: busy ? null : _pickImage,
                    icon: const Icon(Iconsax.camera, size: 18),
                    label: Text(_hasCustomImage ? 'Change photo' : 'Upload photo'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  secondaryAction: _hasCustomImage
                      ? IconButton.outlined(
                          onPressed: busy
                              ? null
                              : () async {
                                  final ok = await showHoldToDeleteSheet(
                                    context,
                                    title: 'Remove image?',
                                    message:
                                        'Hold to clear the custom exercise image.',
                                  );
                                  if (!ok || !mounted) return;
                                  setState(() {
                                    _imageUrl = _defaultExerciseImage;
                                    _imageLink.clear();
                                  });
                                },
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            maximumSize: const Size(44, 44),
                          ),
                          icon: const Icon(Iconsax.trash, size: 18),
                        )
                      : null,
                  linkController: _imageLink,
                  linkHint: 'Paste image URL',
                  onUseLink: busy ? null : _applyImageLink,
                  enabled: !busy,
                ),
                const SizedBox(height: 20),
                _SectionLabel('Demo video'),
                const SizedBox(height: 8),
                _MediaBlock(
                  previewHeight: 148,
                  preview: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_videoUrl.isEmpty)
                        ColoredBox(
                          color: HpColors.subtle,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.video, color: HpColors.mutedForeground),
                              const SizedBox(height: 6),
                              Text(
                                'YouTube, Shorts, Vimeo, or upload',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: HpColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ColoredBox(
                          color: Colors.black,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Iconsax.video_play,
                                  color: HpColors.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _videoUrl,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () => showExerciseVideoViewer(
                                    context,
                                    videoUrl: _videoUrl,
                                    title: _name.text.trim().isEmpty
                                        ? 'Preview'
                                        : _name.text.trim(),
                                  ),
                                  child: const Text('Preview'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_uploading == 'video')
                        const ColoredBox(
                          color: Color(0x990B0B0F),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                  primaryAction: OutlinedButton.icon(
                    onPressed: busy ? null : _pickVideo,
                    icon: const Icon(Iconsax.video_add, size: 18),
                    label: Text(_videoUrl.isEmpty ? 'Upload video' : 'Replace file'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  secondaryAction: _videoUrl.isNotEmpty
                      ? IconButton.outlined(
                          onPressed: busy
                              ? null
                              : () async {
                                  final ok = await showHoldToDeleteSheet(
                                    context,
                                    title: 'Remove video?',
                                    message:
                                        'Hold to clear the demo video for this exercise.',
                                  );
                                  if (!ok || !mounted) return;
                                  setState(() {
                                    _videoUrl = '';
                                    _videoLink.clear();
                                  });
                                },
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            maximumSize: const Size(44, 44),
                          ),
                          icon: const Icon(Iconsax.trash, size: 18),
                        )
                      : null,
                  linkController: _videoLink,
                  linkHint: 'YouTube / Shorts / Vimeo / MP4 URL',
                  onUseLink: busy ? null : _applyVideoLink,
                  enabled: !busy,
                  helper:
                      'Paste any video link or upload MP4 / WEBM / MOV (max 50MB)',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: HpColors.destructive,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + media.padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: HpColors.card,
              border: Border(top: BorderSide(color: HpColors.border)),
            ),
            child: FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: HpColors.mutedForeground,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  const _MediaBlock({
    required this.previewHeight,
    required this.preview,
    required this.primaryAction,
    required this.linkController,
    required this.linkHint,
    required this.onUseLink,
    required this.enabled,
    this.secondaryAction,
    this.helper,
  });

  final double previewHeight;
  final Widget preview;
  final Widget primaryAction;
  final Widget? secondaryAction;
  final TextEditingController linkController;
  final String linkHint;
  final VoidCallback? onUseLink;
  final bool enabled;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HpColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HpColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: previewHeight, child: preview),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: primaryAction),
                    if (secondaryAction != null) ...[
                      const SizedBox(width: 8),
                      secondaryAction!,
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: linkController,
                          enabled: enabled,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: linkHint,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => onUseLink?.call(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: onUseLink,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('Use'),
                      ),
                    ),
                  ],
                ),
                if (helper != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    helper!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: HpColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
