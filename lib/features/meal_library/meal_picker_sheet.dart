import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/list_cards.dart';
import '../../widgets/media_viewer.dart';
import '../../widgets/swipe_row.dart';
import 'meal_edit_sheet.dart';
import 'meal_library_view.dart';

/// Multi-select from the coach's meal library. Swipe a row left to add it,
/// or right to edit it.
Future<List<LibraryMeal>?> showMealPickerSheet(
  BuildContext context, {
  String? dayLabel,
}) {
  return showModalBottomSheet<List<LibraryMeal>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MealPickerSheet(dayLabel: dayLabel),
  );
}

class _MealPickerSheet extends ConsumerStatefulWidget {
  const _MealPickerSheet({this.dayLabel});

  final String? dayLabel;

  @override
  ConsumerState<_MealPickerSheet> createState() => _MealPickerSheetState();
}

class _MealPickerSheetState extends ConsumerState<_MealPickerSheet> {
  /// SwipeRow slide-out (360ms) + collapse (280ms) before the row leaves.
  static const _commitAnimation = Duration(milliseconds: 660);

  final _search = TextEditingController();
  String _q = '';
  String? _type;
  final List<LibraryMeal> _selected = [];
  final Set<String> _hidden = {};
  bool _hintShown = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(LibraryMeal m) async {
    if (_selected.any((x) => x.id == m.id)) return;
    setState(() => _selected.add(m));
    await Future<void>.delayed(_commitAnimation);
    if (!mounted) return;
    setState(() => _hidden.add(m.id));
  }

  void _remove(LibraryMeal m) {
    AppHaptics.selection();
    setState(() {
      _selected.removeWhere((x) => x.id == m.id);
      _hidden.remove(m.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(libraryMealsProvider);
    final all = async.asData?.value ?? const <LibraryMeal>[];
    final filtered = filterLibraryMeals(all, query: _q, type: _type)
        .where((m) => !_hidden.contains(m.id))
        .toList();
    final media = MediaQuery.of(context);

    Widget list;
    if (async.isLoading && async.asData == null) {
      list = const Center(child: CircularProgressIndicator());
    } else if (async.hasError && async.asData == null) {
      list = _Message(
        icon: Iconsax.warning_2,
        text: 'Could not load meals',
        action: TextButton(
          onPressed: () => reloadLibraryMeals(ref),
          child: const Text('Retry'),
        ),
      );
    } else if (filtered.isEmpty) {
      list = _Message(
        icon: all.isEmpty
            ? Icons.restaurant_menu
            : _hidden.isNotEmpty && _q.isEmpty
                ? Iconsax.tick_circle
                : Iconsax.search_status,
        text: all.isEmpty
            ? 'Your meal library is empty'
            : _hidden.isNotEmpty && _q.isEmpty
                ? 'All matching meals added'
                : 'No meals match',
        action: TextButton.icon(
          onPressed: () => editLibraryMeal(context, ref),
          icon: const Icon(Iconsax.add, size: 18),
          label: const Text('Create a meal'),
        ),
      );
    } else {
      list = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: filtered.length,
        itemBuilder: (context, i) {
          final m = filtered[i];
          final showHint = i == 0 && !_hintShown;
          if (showHint) _hintShown = true;
          return SwipeRow(
            key: ValueKey('meal-pick-${m.id}'),
            height: 88,
            radius: 18,
            actionWidth: 88,
            direction: AxisDirection.left,
            commitAt: 0.55,
            fullSwipe: true,
            autoHint: showHint,
            hintLabel: 'Swipe left to add',
            oppositeHintLabel: 'Swipe right to edit',
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
            oppositeActions: const [
              SwipeAction(
                id: 'edit',
                label: 'Edit',
                color: Color(0xFF3B82F6),
                icon: Icon(Iconsax.edit_2, size: 20, color: Colors.white),
              ),
            ],
            onCommit: (_) => _add(m),
            onOpposite: (_) => editLibraryMeal(context, ref, m),
            child: _MealPickRow(meal: m),
          );
        },
      );
    }

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
                              ? 'Meal library'
                              : 'Meal library · ${widget.dayLabel}',
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
                              ? 'Swipe left to add, right to edit'
                              : '${_selected.length} added · left to add, right to edit',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: HpColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'New library meal',
                    onPressed: AppHaptics.wrap(
                      () => editLibraryMeal(context, ref),
                    ),
                    icon: const Icon(Iconsax.add_circle, color: HpColors.primary),
                  ),
                  IconButton(
                    tooltip: 'Close',
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
                  hintText: 'Search meals',
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
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                children: [
                  _TypePill(
                    label: 'All',
                    selected: _type == null,
                    onTap: () => setState(() => _type = null),
                  ),
                  for (final (value, label) in mealLibraryTypes) ...[
                    const SizedBox(width: 8),
                    _TypePill(
                      label: label,
                      selected: _type == value,
                      onTap: () => setState(() => _type = value),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: list),
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

class _TypePill extends StatelessWidget {
  const _TypePill({
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
            color: selected ? HpColors.primaryForeground : HpColors.foreground,
          ),
        ),
      ),
    );
  }
}

class _MealPickRow extends StatelessWidget {
  const _MealPickRow({required this.meal});

  final LibraryMeal meal;

  @override
  Widget build(BuildContext context) {
    final m = meal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          MediaThumb(
            imageUrl: m.imageUrl,
            size: 68,
            icon: Icons.restaurant_menu,
            onTap: m.hasImage
                ? () => showExerciseImageViewer(
                      context,
                      imageUrl: m.imageUrl!.trim(),
                      title: m.name,
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
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${mealTypeLabel(m.type)} · ${m.calories} kcal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HpColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                MealMacroLine(
                  proteinG: m.proteinG,
                  carbsG: m.carbsG,
                  fatG: m.fatG,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: HpColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              text,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: HpColors.foreground,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              action!,
            ],
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

  final List<LibraryMeal> items;
  final ValueChanged<LibraryMeal> onRemove;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final kcal = items.fold<int>(0, (s, m) => s + m.calories);
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
                        meal: items[i],
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
                  ? 'Swipe meals to add'
                  : 'Add ${items.length} ${items.length == 1 ? 'meal' : 'meals'} · $kcal kcal',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrayChip extends StatelessWidget {
  const _TrayChip({required this.meal, required this.onRemove});

  final LibraryMeal meal;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Tooltip(
            message: meal.name,
            child: MediaThumb(
              imageUrl: meal.imageUrl,
              size: 56,
              icon: Icons.restaurant_menu,
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
