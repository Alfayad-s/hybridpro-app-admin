import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/api/admin_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/hold_button.dart';
import '../../../widgets/list_cards.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_targets_sheet.dart';

Future<bool?> showAssignWorkoutSheet(
  BuildContext context, {
  required String clientId,
  AssignedPlan? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AssignWorkoutSheet(
      clientId: clientId,
      existing: existing,
    ),
  );
}

class _AssignWorkoutSheet extends ConsumerStatefulWidget {
  const _AssignWorkoutSheet({
    required this.clientId,
    this.existing,
  });

  final String clientId;
  final AssignedPlan? existing;

  @override
  ConsumerState<_AssignWorkoutSheet> createState() =>
      _AssignWorkoutSheetState();
}

class _AssignWorkoutSheetState extends ConsumerState<_AssignWorkoutSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  late final List<_DayDraft> _days;
  List<Exercise> _catalog = [];
  Map<String, Exercise> _byId = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _selectedDay = 0;

  static const _dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static const _dayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name.text = existing?.name ?? 'Coach plan';
    _description.text = existing?.description ?? '';

    _days = List.generate(7, (i) {
      final dow = i + 1;
      AssignedPlanDay? src;
      if (existing != null) {
        for (final d in existing.days) {
          if (d.dayOfWeek == dow) {
            src = d;
            break;
          }
        }
      }
      final draft = _DayDraft(dayOfWeek: dow);
      if (src != null) {
        draft.isRest = src.isRestDay || src.exercises.isEmpty;
        draft.focus.text = src.isRestDay ? '' : src.muscleFocus;
        draft.exercises = src.exercises
            .map(
              (e) => _PickedExercise(
                exerciseId: e.exerciseId ?? '',
                name: e.name,
                sets: e.targetSets,
                reps: e.targetReps,
                rest: e.restSeconds,
                rpe: e.targetRpe,
                rir: e.targetRir,
              ),
            )
            .toList();
      } else if (!_isEdit && (dow == 1 || dow == 3 || dow == 5)) {
        draft.isRest = false;
      }
      return draft;
    });

    final firstTraining = _days.indexWhere((d) => !d.isRest);
    if (firstTraining >= 0) _selectedDay = firstTraining;

    _loadCatalog();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final d in _days) {
      d.focus.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final list = await ref.read(adminRepositoryProvider).exercises();
      if (!mounted) return;
      setState(() {
        _catalog = list;
        _byId = {for (final e in list) e.id: e};
        final byName = {for (final e in list) e.name.toLowerCase(): e};
        for (final day in _days) {
          for (final p in day.exercises) {
            if (p.exerciseId.isEmpty) {
              final match = byName[p.name.toLowerCase()];
              if (match != null) p.exerciseId = match.id;
            }
          }
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _metaFor(Exercise? e) {
    if (e == null) return '';
    return [
      if (e.muscleGroup.trim().isNotEmpty) e.muscleGroup.trim(),
      if (e.equipment.trim().isNotEmpty) e.equipment.trim(),
    ].join(' · ');
  }

  Future<void> _pickExercises() async {
    final day = _days[_selectedDay];
    if (day.isRest) return;

    final picked = await showExercisePickerSheet(
      context,
      catalog: _catalog,
      excludeIds: day.exercises.map((e) => e.exerciseId).toSet(),
      dayLabel: _dayLabels[day.dayOfWeek],
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      for (final e in picked) {
        day.exercises.add(_PickedExercise(exerciseId: e.id, name: e.name));
      }
    });
  }

  Future<void> _editExercise(_PickedExercise p) async {
    final ex = _byId[p.exerciseId];
    final result = await showExerciseTargetsSheet(
      context,
      name: p.name,
      imageUrl: ex?.imageUrl,
      videoUrl: ex?.videoUrl,
      meta: _metaFor(ex),
      initial: ExerciseTargets(
        sets: p.sets,
        reps: p.reps,
        rest: p.rest,
        rpe: p.rpe,
        rir: p.rir,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        p.sets = result.sets;
        p.reps = result.reps;
        p.rest = result.rest;
        p.rpe = result.rpe;
        p.rir = result.rir;
      });
    }
  }

  Future<void> _removeExercise(_DayDraft day, int index) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Remove exercise?',
      message: 'Hold to remove "${day.exercises[index].name}" from this day.',
    );
    if (!ok || !mounted) return;
    setState(() => day.exercises.removeAt(index));
  }

  void _copyDay(int fromIndex, int toIndex) {
    final from = _days[fromIndex];
    final to = _days[toIndex];
    setState(() {
      to.isRest = from.isRest;
      to.focus.text = from.focus.text;
      to.exercises = from.exercises
          .map(
            (e) => _PickedExercise(
              exerciseId: e.exerciseId,
              name: e.name,
              sets: e.sets,
              reps: e.reps,
              rest: e.rest,
              rpe: e.rpe,
              rir: e.rir,
            ),
          )
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${_dayLabels[from.dayOfWeek]} to ${_dayLabels[to.dayOfWeek]}',
        ),
      ),
    );
  }

  Future<void> _clearDay(int index) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Clear ${_dayLabels[_days[index].dayOfWeek]}?',
      message: 'Hold to turn this day into a rest day and remove its exercises.',
      holdLabel: 'Hold to clear',
      doneLabel: 'Cleared',
    );
    if (!ok || !mounted) return;
    setState(() {
      _days[index].isRest = true;
      _days[index].focus.clear();
      _days[index].exercises.clear();
    });
  }

  List<Map<String, dynamic>> _daysPayload() {
    return _days.map((d) {
      final rest = d.isRest || d.exercises.isEmpty;
      return {
        'dayOfWeek': d.dayOfWeek,
        'name': _dayLabels[d.dayOfWeek],
        'muscleFocus': rest
            ? 'Rest'
            : (d.focus.text.trim().isEmpty ? 'Training' : d.focus.text.trim()),
        'isRestDay': rest,
        'exercises': rest
            ? <Map<String, dynamic>>[]
            : d.exercises
                .where((e) => e.exerciseId.isNotEmpty)
                .map(
                  (e) => {
                    'exerciseId': e.exerciseId,
                    'targetSets': e.sets,
                    'targetReps': e.reps,
                    'restSeconds': e.rest,
                    if (e.rpe != null) 'targetRpe': e.rpe,
                    if (e.rir != null) 'targetRir': e.rir,
                  },
                )
                .toList(),
      };
    }).toList();
  }

  Future<void> _submit() async {
    final hasTraining = _days.any(
      (d) => !d.isRest && d.exercises.any((e) => e.exerciseId.isNotEmpty),
    );
    if (!hasTraining) {
      setState(() => _error = 'Add exercises to at least one training day');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final days = _daysPayload();
      final description =
          _description.text.trim().isEmpty ? null : _description.text.trim();
      if (_isEdit) {
        await repo.updateWorkout(
          widget.clientId,
          widget.existing!.id,
          name: _name.text.trim(),
          description: description,
          days: days,
        );
      } else {
        await repo.assignWorkout(
          widget.clientId,
          name: _name.text.trim(),
          description: description,
          days: days,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = ((mq.size.height - mq.viewInsets.bottom) * 0.94)
        .clamp(320.0, mq.size.height * 0.94);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: height,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit plan' : 'Assign personalized plan',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: HpColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set different workouts for each weekday',
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
            _buildFooter(mq),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final day = _days[_selectedDay];
    final trainingCount =
        _days.where((d) => !d.isRest && d.exercises.isNotEmpty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const _SectionLabel('Plan details'),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Plan name',
            prefixIcon: Icon(Iconsax.note_2, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Assigned by your coach',
            prefixIcon: Icon(Iconsax.message_text, size: 20),
          ),
        ),
        const SizedBox(height: 26),
        _SectionLabel(
          'Weekly schedule',
          trailing: '$trainingCount training ${trainingCount == 1 ? 'day' : 'days'}',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _DayTile(
                  label: _dayLabels[_days[i].dayOfWeek]!,
                  count: _days[i].isRest ? 0 : _days[i].exercises.length,
                  isRest: _days[i].isRest,
                  selected: i == _selectedDay,
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _selectedDay = i);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _DayCard(
          dayName: _dayNames[day.dayOfWeek]!,
          isRest: day.isRest,
          focus: day.focus,
          onTrainingChanged: (training) {
            AppHaptics.selection();
            setState(() {
              day.isRest = !training;
              if (!training) day.exercises.clear();
            });
          },
        ),
        if (!day.isRest) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const _SectionLabel('Exercises'),
              if (day.exercises.isNotEmpty) ...[
                const SizedBox(width: 8),
                _CountBadge(day.exercises.length),
              ],
              const Spacer(),
              _PillButton(
                icon: Icons.add_rounded,
                label: 'Add',
                onTap: _pickExercises,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (day.exercises.isEmpty)
            _EmptyExercises(
              dayLabel: _dayLabels[day.dayOfWeek]!,
              onTap: _pickExercises,
            )
          else
            for (var i = 0; i < day.exercises.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _ExerciseCard(
                index: i + 1,
                exercise: day.exercises[i],
                catalog: _byId[day.exercises[i].exerciseId],
                meta: _metaFor(_byId[day.exercises[i].exerciseId]),
                onEdit: () => _editExercise(day.exercises[i]),
                onRemove: () => _removeExercise(day, i),
              ),
            ],
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: PopupMenuButton<int>(
                onSelected: (to) => _copyDay(_selectedDay, to),
                color: HpColors.popover,
                itemBuilder: (_) => [
                  for (var i = 0; i < 7; i++)
                    if (i != _selectedDay)
                      PopupMenuItem(
                        value: i,
                        child: Text('Copy to ${_dayNames[_days[i].dayOfWeek]}'),
                      ),
                ],
                child: const _OutlineAction(
                  icon: Iconsax.copy,
                  label: 'Copy day to…',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: AppHaptics.wrap(() => _clearDay(_selectedDay)),
                child: const _OutlineAction(
                  icon: Iconsax.trash,
                  label: 'Clear day',
                  color: HpColors.destructive,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(MediaQueryData mq) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + (mq.viewInsets.bottom > 0 ? 0 : mq.padding.bottom),
      ),
      decoration: const BoxDecoration(
        color: HpColors.card,
        border: Border(top: BorderSide(color: HpColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Row(
              children: [
                const Icon(
                  Iconsax.info_circle,
                  size: 16,
                  color: HpColors.destructive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: HpColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed:
                _saving || _loading ? null : AppHaptics.wrap(_submit),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              _saving
                  ? (_isEdit ? 'Saving…' : 'Assigning…')
                  : (_isEdit ? 'Save plan' : 'Assign plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: HpColors.foreground,
      ),
    );
    if (trailing == null) return label;
    return Row(
      children: [
        label,
        const Spacer(),
        Text(
          trailing!,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: HpColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: HpColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: HpColors.primary,
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.label,
    required this.count,
    required this.isRest,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isRest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = isRest ? 'Rest' : (count == 0 ? '—' : '$count ex');
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 62,
        decoration: BoxDecoration(
          color: selected
              ? HpColors.primary
              : (isRest ? HpColors.subtle : HpColors.primary.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? HpColors.primary
                : (isRest
                    ? HpColors.border
                    : HpColors.primary.withValues(alpha: 0.3)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected
                    ? HpColors.primaryForeground
                    : HpColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected
                    ? HpColors.primaryForeground.withValues(alpha: 0.75)
                    : (isRest ? HpColors.mutedForeground : HpColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.dayName,
    required this.isRest,
    required this.focus,
    required this.onTrainingChanged,
  });

  final String dayName;
  final bool isRest;
  final TextEditingController focus;
  final ValueChanged<bool> onTrainingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HpColors.subtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isRest
                      ? HpColors.card
                      : HpColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isRest ? Iconsax.moon : Iconsax.weight,
                  size: 20,
                  color: isRest ? HpColors.mutedForeground : HpColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HpColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRest
                          ? 'Rest day — no workout scheduled'
                          : 'Training day',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: HpColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: !isRest,
                onChanged: onTrainingChanged,
              ),
            ],
          ),
          if (!isRest) ...[
            const SizedBox(height: 14),
            TextField(
              controller: focus,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Muscle focus',
                hintText: 'e.g. Push, Pull, Legs',
                prefixIcon: Icon(Iconsax.flash_1, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HpColors.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: HpColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
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

class _EmptyExercises extends StatelessWidget {
  const _EmptyExercises({required this.dayLabel, required this.onTap});

  final String dayLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HpColors.subtle,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HpColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HpColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: HpColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'No exercises for $dayLabel yet',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HpColors.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to open the exercise library',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: HpColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.catalog,
    required this.meta,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final _PickedExercise exercise;
  final Exercise? catalog;
  final String meta;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HpColors.subtle,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: AppHaptics.wrap(onEdit),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HpColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      MediaThumb(
                        imageUrl: catalog?.imageUrl,
                        size: 54,
                        icon: Iconsax.weight,
                      ),
                      Positioned(
                        left: -4,
                        top: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: HpColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: HpColors.subtle,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$index',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: HpColors.primaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: HpColors.foreground,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
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
                  _RoundIcon(
                    icon: Iconsax.edit_2,
                    tooltip: 'Edit targets',
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 6),
                  _RoundIcon(
                    icon: Iconsax.trash,
                    tooltip: 'Remove',
                    color: HpColors.destructive,
                    onTap: onRemove,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TargetTile(label: 'Sets', value: '${exercise.sets}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TargetTile(label: 'Reps', value: '${exercise.reps}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TargetTile(
                      label: 'Rest',
                      value: formatRest(exercise.rest),
                    ),
                  ),
                ],
              ),
              if (exercise.rpe != null || exercise.rir != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (exercise.rpe != null)
                      Expanded(
                        child: _TargetTile(
                          label: 'RPE',
                          value: '${exercise.rpe}',
                        ),
                      ),
                    if (exercise.rpe != null && exercise.rir != null)
                      const SizedBox(width: 8),
                    if (exercise.rir != null)
                      Expanded(
                        child: _TargetTile(
                          label: 'RIR',
                          value: '${exercise.rir}',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = HpColors.foreground,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: HpColors.card,
        shape: const CircleBorder(side: BorderSide(color: HpColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: AppHaptics.wrap(onTap),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HpColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: HpColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: HpColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    this.color = HpColors.foreground,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HpColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDraft {
  _DayDraft({required this.dayOfWeek});

  final int dayOfWeek;
  final focus = TextEditingController();
  bool isRest = true;
  List<_PickedExercise> exercises = [];
}

class _PickedExercise {
  _PickedExercise({
    required this.exerciseId,
    required this.name,
    this.sets = 3,
    this.reps = 10,
    this.rest = 90,
    this.rpe,
    this.rir,
  });

  String exerciseId;
  final String name;
  int sets;
  int reps;
  int rest;
  int? rpe;
  int? rir;
}
