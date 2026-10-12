import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/list_cards.dart';

const _dayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _cardColor = Color(0xFF121214);
const _summaryColor = Color(0xFF1A1A1E);
const _addColor = Color(0xFF2A2A30);

/// Rough per-set working time used for the session estimate.
const _secondsPerSet = 40;

/// Coach workout plan in the same layout as the meal plan view: day picker,
/// daily summary bar, and one card per exercise with its sets.
class AssignedPlanCard extends StatefulWidget {
  const AssignedPlanCard({
    super.key,
    required this.plan,
    this.onEdit,
    this.onDelete,
  });

  final AssignedPlan plan;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<AssignedPlanCard> createState() => _AssignedPlanCardState();
}

class _AssignedPlanCardState extends State<AssignedPlanCard> {
  late int _selected = _initialDay();

  Map<int, AssignedPlanDay> get _trainingDays => {
        for (final d in widget.plan.days)
          if (d.dayOfWeek >= 1 &&
              d.dayOfWeek <= 7 &&
              !d.isRestDay &&
              d.exercises.isNotEmpty)
            d.dayOfWeek: d,
      };

  int _initialDay() {
    final today = DateTime.now().weekday;
    final days = _trainingDays.keys.toList()..sort();
    if (days.isEmpty || days.contains(today)) return today;
    return days.first;
  }

  @override
  Widget build(BuildContext context) {
    final training = _trainingDays;
    final day = training[_selected];
    final exercises = day?.exercises ?? const <AssignedPlanExercise>[];
    final totalSets = exercises.fold<int>(0, (s, e) => s + e.targetSets);
    final totalReps =
        exercises.fold<int>(0, (s, e) => s + e.targetSets * e.targetReps);
    final seconds = exercises.fold<int>(
      0,
      (s, e) => s + e.targetSets * (_secondsPerSet + e.restSeconds),
    );
    final minutes = (seconds / 60).round();
    final exerciseCount =
        training.values.fold<int>(0, (s, d) => s + d.exercises.length);
    final isToday = _selected == DateTime.now().weekday;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanHeader(
            plan: widget.plan,
            trainingDays: training.keys.toSet(),
            exerciseCount: exerciseCount,
            selected: _selected,
            onSelect: (d) => setState(() => _selected = d),
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
          const SizedBox(height: 18),
          Text(
            isToday
                ? "Today's Workout"
                : "${_dayLong[_selected - 1]}'s Workout",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: HpColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          if (day == null)
            _RestDayCard(onAdd: widget.onEdit)
          else ...[
            _SummaryBar(
              focus: day.muscleFocus.isNotEmpty
                  ? day.muscleFocus
                  : (day.name.isNotEmpty ? day.name : 'Training'),
              minutes: minutes,
              exercises: exercises.length,
              sets: totalSets,
              reps: totalReps,
              setsPerExercise: [for (final e in exercises) e.targetSets],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < exercises.length; i++) ...[
              _ExerciseCard(index: i + 1, exercise: exercises[i]),
              const SizedBox(height: 12),
            ],
            if (widget.onEdit != null) _AddExerciseCard(onTap: widget.onEdit!),
          ],
        ],
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.plan,
    required this.trainingDays,
    required this.exerciseCount,
    required this.selected,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
  });

  final AssignedPlan plan;
  final Set<int> trainingDays;
  final int exerciseCount;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _summaryColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HpColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Iconsax.weight,
                  size: 22,
                  color: HpColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: HpColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          label: plan.isActive ? 'Active' : 'Inactive',
                          tone: plan.isActive
                              ? StatusPillTone.success
                              : StatusPillTone.neutral,
                        ),
                        Text(
                          '${trainingDays.length} days · $exerciseCount exercises',
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
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                CardRoundAction(
                  icon: Iconsax.edit_2,
                  tooltip: 'Edit',
                  onTap: onEdit!,
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                CardRoundAction(
                  icon: Iconsax.trash,
                  tooltip: 'Unassign',
                  color: HpColors.destructive,
                  onTap: onDelete!,
                ),
              ],
            ],
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              plan.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: HpColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) const SizedBox(width: 6),
                Expanded(
                  child: _DayChip(
                    label: _dayShort[d - 1],
                    selected: d == selected,
                    isTraining: trainingDays.contains(d),
                    isToday: d == DateTime.now().weekday,
                    onTap: () => onSelect(d),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.isTraining,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isTraining;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppHaptics.wrap(onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? HpColors.primary : HpColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? HpColors.primary
                : isToday
                    ? HpColors.primary.withValues(alpha: 0.5)
                    : HpColors.border,
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
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !isTraining
                    ? Colors.transparent
                    : selected
                        ? HpColors.primaryForeground
                        : HpColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.focus,
    required this.minutes,
    required this.exercises,
    required this.sets,
    required this.reps,
    required this.setsPerExercise,
  });

  final String focus;
  final int minutes;
  final int exercises;
  final int sets;
  final int reps;
  final List<int> setsPerExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _summaryColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  focus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Iconsax.timer_1, size: 14, color: HpColors.primary),
              const SizedBox(width: 5),
              Text(
                '~$minutes min',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HpColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (var i = 0; i < setsPerExercise.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: setsPerExercise[i] <= 0 ? 1 : setsPerExercise[i],
                      child: ColoredBox(
                        color: i.isEven
                            ? HpColors.primary
                            : HpColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$exercises exercises · $sets sets · $reps reps',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: HpColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.index, required this.exercise});

  final int index;
  final AssignedPlanExercise exercise;

  @override
  Widget build(BuildContext context) {
    final name = exercise.name.trim().isEmpty ? 'Exercise' : exercise.name.trim();
    final sets = exercise.targetSets <= 0 ? 1 : exercise.targetSets;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HpColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: HpColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Iconsax.clock, size: 14, color: HpColors.primary),
              const SizedBox(width: 6),
              Text(
                '${exercise.restSeconds}s rest',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HpColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var s = 1; s <= sets; s++) ...[
                        if (s > 1) const SizedBox(width: 10),
                        _SetTile(set: s, reps: exercise.targetReps),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  [
                    '$sets × ${exercise.targetReps}',
                    if (exercise.targetRpe != null) 'RPE ${exercise.targetRpe}',
                    if (exercise.targetRir != null) 'RIR ${exercise.targetRir}',
                  ].join(' · '),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: HpColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.set, required this.reps});

  final int set;
  final int reps;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HpColors.subtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$reps',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: HpColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'reps',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: HpColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set $set',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: HpColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: HpColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: HpColors.subtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Iconsax.moon,
              size: 24,
              color: HpColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rest day',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  onAdd != null
                      ? 'Recovery — tap + to add training'
                      : 'Recovery — no training planned',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: HpColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (onAdd != null) _AddTile(onTap: onAdd!),
        ],
      ),
    );
  }
}

class _AddExerciseCard extends StatelessWidget {
  const _AddExerciseCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: HpColors.border),
          ),
          child: Row(
            children: [
              const _AddTileBox(),
              const SizedBox(width: 14),
              Text(
                'Add or edit exercises',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _addColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        borderRadius: BorderRadius.circular(14),
        child: const SizedBox(
          width: 58,
          height: 58,
          child: Icon(Icons.add, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _AddTileBox extends StatelessWidget {
  const _AddTileBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _addColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 22),
    );
  }
}

class CardRoundAction extends StatelessWidget {
  const CardRoundAction({
    super.key,
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
        color: HpColors.subtle,
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
