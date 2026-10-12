import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/list_cards.dart';
import 'assigned_plan_card.dart';

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

/// Same slots and windows as the member app's "Today's Meal".
const _slots = <(String, String, String)>[
  ('breakfast', 'Breakfast', '06:00am - 10:00am'),
  ('lunch', 'Lunch', '12:00pm - 03:00pm'),
  ('dinner', 'Dinner', '07:00pm - 10:00pm'),
  ('snack', 'Snack', 'Anytime'),
];

const _slotCardColor = Color(0xFF121214);
const _summaryColor = Color(0xFF1A1A1E);
const _trackColor = Color(0xFF2A2A2E);
const _addColor = Color(0xFF2A2A30);
const _proteinColor = Color(0xFFA0D028);
const _carbsColor = Color(0xFF38BDF8);
const _fatColor = Color(0xFFF59E0B);

/// Coach meal plan rendered like the member app's "Today's Meal": a day
/// picker, a daily summary bar, and one card per meal slot.
class AssignedMealPlanCard extends StatefulWidget {
  const AssignedMealPlanCard({
    super.key,
    required this.plan,
    this.onEdit,
    this.onDelete,
  });

  final AssignedMealPlan plan;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<AssignedMealPlanCard> createState() => _AssignedMealPlanCardState();
}

class _AssignedMealPlanCardState extends State<AssignedMealPlanCard> {
  late int _selected = _initialDay();

  Map<int, List<AssignedMealSlot>> get _byDay {
    final out = <int, List<AssignedMealSlot>>{};
    for (final d in widget.plan.days) {
      if (d.dayOfWeek < 1 || d.dayOfWeek > 7 || d.meals.isEmpty) continue;
      out.putIfAbsent(d.dayOfWeek, () => []).addAll(d.meals);
    }
    return out;
  }

  int _initialDay() {
    final today = DateTime.now().weekday;
    final days = _byDay.keys.toList()..sort();
    if (days.isEmpty || days.contains(today)) return today;
    return days.first;
  }

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay;
    final meals = byDay[_selected] ?? const <AssignedMealSlot>[];
    final kcal = meals.fold<int>(0, (s, m) => s + m.calories);
    final p = meals.fold<int>(0, (s, m) => s + m.proteinG);
    final c = meals.fold<int>(0, (s, m) => s + m.carbsG);
    final f = meals.fold<int>(0, (s, m) => s + m.fatG);
    final isToday = _selected == DateTime.now().weekday;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanHeader(
            plan: widget.plan,
            activeDays: byDay.keys.toSet(),
            selected: _selected,
            onSelect: (d) => setState(() => _selected = d),
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
          const SizedBox(height: 18),
          Text(
            isToday ? "Today's Meal" : "${_dayLong[_selected - 1]}'s Meal",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: HpColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryBar(
            kcal: kcal,
            mealCount: meals.length,
            proteinG: p,
            carbsG: c,
            fatG: f,
          ),
          const SizedBox(height: 12),
          for (final (type, title, range) in _slots) ...[
            _SlotCard(
              title: title,
              timeRange: range,
              meals: meals
                  .where((m) => _slotOf(m.type) == type)
                  .toList(),
              onAdd: widget.onEdit,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  String _slotOf(String raw) {
    final t = raw.toLowerCase();
    return _slots.any((s) => s.$1 == t) ? t : 'snack';
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.plan,
    required this.activeDays,
    required this.selected,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
  });

  final AssignedMealPlan plan;
  final Set<int> activeDays;
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
                  Icons.restaurant_menu,
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
                          '${activeDays.length} days · ${plan.mealCount} meals',
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
                    hasMeals: activeDays.contains(d),
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
    required this.hasMeals,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool hasMeals;
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
                color: !hasMeals
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
    required this.kcal,
    required this.mealCount,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int kcal;
  final int mealCount;
  final int proteinG;
  final int carbsG;
  final int fatG;

  @override
  Widget build(BuildContext context) {
    final macroKcal = proteinG * 4 + carbsG * 4 + fatG * 9;

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
                  '$kcal kcal planned',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$mealCount ${mealCount == 1 ? 'meal' : 'meals'}',
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
              child: macroKcal <= 0
                  ? const ColoredBox(color: _trackColor)
                  : Row(
                      children: [
                        if (proteinG > 0)
                          Expanded(
                            flex: proteinG * 4,
                            child: const ColoredBox(color: _proteinColor),
                          ),
                        if (carbsG > 0)
                          Expanded(
                            flex: carbsG * 4,
                            child: const ColoredBox(color: _carbsColor),
                          ),
                        if (fatG > 0)
                          Expanded(
                            flex: fatG * 9,
                            child: const ColoredBox(color: _fatColor),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MacroLegend(color: _proteinColor, label: 'P ${proteinG}g'),
              const SizedBox(width: 14),
              _MacroLegend(color: _carbsColor, label: 'C ${carbsG}g'),
              const SizedBox(width: 14),
              _MacroLegend(color: _fatColor, label: 'F ${fatG}g'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: HpColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.title,
    required this.timeRange,
    required this.meals,
    this.onAdd,
  });

  final String title;
  final String timeRange;
  final List<AssignedMealSlot> meals;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final total = meals.fold<int>(0, (s, m) => s + m.calories);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _slotCardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
              ),
              const Icon(Iconsax.clock, size: 14, color: HpColors.primary),
              const SizedBox(width: 6),
              Text(
                timeRange,
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
                      for (final m in meals) ...[
                        _FoodThumb(meal: m),
                        const SizedBox(width: 10),
                      ],
                      if (onAdd != null) _AddChip(onTap: onAdd!),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  '$total kcal',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: HpColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          if (meals.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: onAdd != null ? 4 : 0),
              child: Text(
                onAdd != null
                    ? 'No meals planned — tap + to add'
                    : 'No meals planned',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: HpColors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoodThumb extends StatelessWidget {
  const _FoodThumb({required this.meal});

  final AssignedMealSlot meal;

  @override
  Widget build(BuildContext context) {
    final name = meal.name.trim().isEmpty ? 'Meal' : meal.name.trim();

    return GestureDetector(
      onTap: AppHaptics.wrap(() => _showDetails(context, name)),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: HpColors.subtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: meal.hasImage
                  ? Image.network(
                      meal.imageUrl!,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _initial(name),
                    )
                  : _initial(name),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HpColors.foreground,
              ),
            ),
            Text(
              '${meal.calories} kcal',
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: HpColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial(String name) {
    return Center(
      child: Text(
        name[0].toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: HpColors.primary,
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, String name) {
    final notes = (meal.notes ?? '').trim();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HpColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meal.hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      meal.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: HpColors.subtle,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: HpColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HpColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${meal.calories} kcal',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HpColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MacroBox(label: 'Protein', grams: meal.proteinG),
                  const SizedBox(width: 8),
                  _MacroBox(label: 'Carbs', grams: meal.carbsG),
                  const SizedBox(width: 8),
                  _MacroBox(label: 'Fat', grams: meal.fatG),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  notes,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: HpColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroBox extends StatelessWidget {
  const _MacroBox({required this.label, required this.grams});

  final String label;
  final int grams;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: HpColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HpColors.border),
        ),
        child: Column(
          children: [
            Text(
              '${grams}g',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HpColors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: HpColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

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
