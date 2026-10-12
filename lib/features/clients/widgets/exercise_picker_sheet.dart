import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/exercise_media.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/list_cards.dart';
import '../../../widgets/media_viewer.dart';
import '../../../widgets/swipe_row.dart';

/// Multi-select exercise library — swipe a row left to add it (same gesture
/// as the member app's "Build your workout").
Future<List<Exercise>?> showExercisePickerSheet(
  BuildContext context, {
  required List<Exercise> catalog,
  Set<String> excludeIds = const {},
  String? dayLabel,
}) {
  return showModalBottomSheet<List<Exercise>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExercisePickerSheet(
      catalog: catalog,
      excludeIds: excludeIds,
      dayLabel: dayLabel,
    ),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({
    required this.catalog,
    required this.excludeIds,
    this.dayLabel,
  });

  final List<Exercise> catalog;
  final Set<String> excludeIds;
  final String? dayLabel;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  /// SwipeRow slide-out (360ms) + collapse (280ms) before the row leaves.
  static const _commitAnimation = Duration(milliseconds: 660);

  final _search = TextEditingController();
  String _q = '';
  String? _muscle;
  final List<Exercise> _selected = [];
  final Set<String> _hidden = {};
  bool _hintShown = false;

  late final List<String> _muscles = () {
    final set = <String>{};
    for (final e in widget.catalog) {
      final m = e.muscleGroup.trim();
      if (m.isNotEmpty) set.add(m);
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(Exercise e) async {
    if (_selected.any((x) => x.id == e.id)) return;
    setState(() => _selected.add(e));
    await Future<void>.delayed(_commitAnimation);
    if (!mounted) return;
    setState(() => _hidden.add(e.id));
  }

  void _remove(Exercise e) {
    AppHaptics.selection();
    setState(() {
      _selected.removeWhere((x) => x.id == e.id);
      _hidden.remove(e.id);
    });
  }

  String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final filtered = widget.catalog.where((e) {
      if (widget.excludeIds.contains(e.id) || _hidden.contains(e.id)) {
        return false;
      }
      if (_muscle != null &&
          e.muscleGroup.trim().toLowerCase() != _muscle!.toLowerCase()) {
        return false;
      }
      if (q.isEmpty) return true;
      return '${e.name} ${e.muscleGroup} ${e.target} ${e.equipment}'
          .toLowerCase()
          .contains(q);
    }).toList();

    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.9,
        decoration: const BoxDecoration(
          color: HpColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dayLabel == null
                              ? 'Add exercises'
                              : 'Add exercises · ${widget.dayLabel}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: HpColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selected.isEmpty
                              ? 'Swipe left on an exercise to add'
                              : '${_selected.length} added · swipe to add more',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: HpColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: AppHaptics.wrap(() => Navigator.pop(context)),
                    icon: const Icon(
                      Iconsax.close_circle,
                      color: HpColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _q = v.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name, muscle, equipment',
                  prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _q = '');
                          },
                          icon: const Icon(Iconsax.close_circle, size: 18),
                        ),
                  fillColor: HpColors.subtle,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: HpColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            if (_muscles.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  itemCount: _muscles.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final value = i == 0 ? null : _muscles[i - 1];
                    final selected = _muscle == value;
                    return _FilterPill(
                      label: value == null ? 'All' : _label(value),
                      selected: selected,
                      onTap: () => setState(() => _muscle = value),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyResults(allAdded: _hidden.isNotEmpty && q.isEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        final showHint = i == 0 && !_hintShown;
                        if (showHint) _hintShown = true;
                        return SwipeRow(
                          key: ValueKey('pick-${e.id}'),
                          height: 88,
                          radius: 18,
                          actionWidth: 88,
                          direction: AxisDirection.left,
                          commitAt: 0.55,
                          fullSwipe: true,
                          autoHint: showHint,
                          hintLabel: 'Swipe to add',
                          actionColor: HpColors.primary,
                          drawerColor: const Color(0xFF3F3F46),
                          rowColor: const Color(0xFF27272A),
                          textColor: const Color(0xFFF5F5F5),
                          margin: const EdgeInsets.only(bottom: 8),
                          actions: const [
                            SwipeAction(
                              id: 'add',
                              label: 'Add',
                              color: HpColors.primary,
                              icon: Icon(
                                Iconsax.add,
                                size: 20,
                                color: HpColors.primaryForeground,
                              ),
                            ),
                          ],
                          onCommit: (_) => _add(e),
                          child: _ExerciseRow(exercise: e),
                        );
                      },
                    ),
            ),
            _AddedTray(
              items: _selected,
              onRemove: _remove,
              onDone: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, List.of(_selected)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppHaptics.wrap(onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? HpColors.primary : HpColors.subtle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? HpColors.primary : HpColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                selected ? HpColors.primaryForeground : HpColors.foreground,
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final meta = [
      if (e.muscleGroup.trim().isNotEmpty) e.muscleGroup.trim(),
      if (e.target.trim().isNotEmpty &&
          e.target.trim().toLowerCase() != e.muscleGroup.trim().toLowerCase())
        e.target.trim(),
      if (e.equipment.trim().isNotEmpty) e.equipment.trim(),
    ].join(' · ');
    final hasImage = hasExerciseImage(e.imageUrl);
    final hasVideo = hasExerciseVideo(e.videoUrl);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          MediaThumb(
            imageUrl: e.imageUrl,
            size: 68,
            icon: Iconsax.weight,
            onTap: hasImage
                ? () => showExerciseImageViewer(
                      context,
                      imageUrl: e.imageUrl!.trim(),
                      title: e.name,
                    )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  e.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: HpColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasVideo)
            _DemoButton(
              onTap: () => showExerciseVideoViewer(
                context,
                videoUrl: e.videoUrl!.trim(),
                title: e.name,
              ),
            )
          else
            Icon(
              Iconsax.arrow_left_2,
              size: 16,
              color: HpColors.mutedForeground.withValues(alpha: 0.45),
            ),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HpColors.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.video_play, size: 18, color: HpColors.primary),
              const SizedBox(height: 2),
              Text(
                'Demo',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: HpColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.allAdded});

  final bool allAdded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allAdded ? Iconsax.tick_circle : Iconsax.search_status,
              size: 36,
              color: HpColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              allAdded ? 'All matching exercises added' : 'No exercises match',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: HpColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddedTray extends StatelessWidget {
  const _AddedTray({
    required this.items,
    required this.onRemove,
    required this.onDone,
  });

  final List<Exercise> items;
  final ValueChanged<Exercise> onRemove;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HpColors.popover,
        border: Border(top: BorderSide(color: HpColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: items.isEmpty
                ? const SizedBox(width: double.infinity)
                : SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => _TrayChip(
                        exercise: items[i],
                        onRemove: () => onRemove(items[i]),
                      ),
                    ),
                  ),
          ),
          if (items.isNotEmpty) const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onDone == null ? null : AppHaptics.wrap(onDone!),
            icon: const Icon(Iconsax.tick_circle, size: 18),
            label: Text(
              items.isEmpty
                  ? 'Swipe exercises to add'
                  : 'Add ${items.length} ${items.length == 1 ? 'exercise' : 'exercises'}',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrayChip extends StatelessWidget {
  const _TrayChip({required this.exercise, required this.onRemove});

  final Exercise exercise;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Tooltip(
            message: exercise.name,
            child: MediaThumb(
              imageUrl: exercise.imageUrl,
              size: 56,
              icon: Iconsax.weight,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: HpColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: HpColors.border),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: HpColors.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
