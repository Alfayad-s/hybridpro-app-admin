import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/common.dart';
import '../../widgets/hold_button.dart';
import '../../widgets/list_cards.dart';
import '../../widgets/media_viewer.dart';
import 'meal_edit_sheet.dart';

Future<void> reloadLibraryMeals(WidgetRef ref) {
  ref.invalidate(libraryMealsProvider);
  return ref.read(libraryMealsProvider.future);
}

/// Create or edit a library meal, then refresh the library.
Future<void> editLibraryMeal(
  BuildContext context,
  WidgetRef ref, [
  LibraryMeal? existing,
]) async {
  final body = await showMealEditSheet(context, existing: existing);
  if (body == null || !context.mounted) return;
  try {
    final repo = ref.read(adminRepositoryProvider);
    if (existing == null) {
      await repo.createLibraryMeal(body);
    } else {
      await repo.updateLibraryMeal(existing.id, body);
    }
    await reloadLibraryMeals(ref);
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

List<LibraryMeal> filterLibraryMeals(
  List<LibraryMeal> meals, {
  String query = '',
  String? type,
}) {
  final q = query.trim().toLowerCase();
  return [
    for (final m in meals)
      if ((type == null || m.type == type) &&
          (q.isEmpty || m.name.toLowerCase().contains(q)))
        m,
  ];
}

class MealLibraryView extends ConsumerStatefulWidget {
  const MealLibraryView({super.key, required this.query});

  final String query;

  @override
  ConsumerState<MealLibraryView> createState() => _MealLibraryViewState();
}

class _MealLibraryViewState extends ConsumerState<MealLibraryView> {
  String? _type;

  Future<void> _delete(LibraryMeal meal) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Delete meal?',
      message: meal.name,
    );
    if (!ok) return;
    try {
      await ref.read(adminRepositoryProvider).deleteLibraryMeal(meal.id);
      await reloadLibraryMeals(ref);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(libraryMealsProvider);
    final all = async.asData?.value ?? const <LibraryMeal>[];
    final items = filterLibraryMeals(all, query: widget.query, type: _type);
    final showBlocking = async.isLoading && async.asData?.value == null;

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterPill(
                label: 'All · ${all.length}',
                selected: _type == null,
                onTap: () => setState(() => _type = null),
              ),
              for (final (value, label) in mealLibraryTypes) ...[
                const SizedBox(width: PageInsets.chipGap),
                _FilterPill(
                  label:
                      '$label · ${all.where((m) => m.type == value).length}',
                  selected: _type == value,
                  onTap: () => setState(() => _type = value),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: AsyncBody(
            loading: showBlocking,
            error: async.hasError && async.asData?.value == null
                ? async.error.toString()
                : null,
            onRetry: () => reloadLibraryMeals(ref),
            empty: !showBlocking && items.isEmpty,
            emptyLabel: all.isEmpty
                ? 'No meals yet — tap + to add one'
                : 'No meals match',
            child: RefreshIndicator(
              onRefresh: () => reloadLibraryMeals(ref),
              child: ListView.separated(
                padding: PageInsets.page.copyWith(top: 12),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: PageInsets.cardGap),
                itemBuilder: (_, i) => LibrarySwipeCard(
                  showHint: i == 0,
                  onEdit: () => editLibraryMeal(context, ref, items[i]),
                  onDelete: () => _delete(items[i]),
                  child: _MealRow(
                    meal: items[i],
                    onEdit: () => editLibraryMeal(context, ref, items[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.meal,
    required this.onEdit,
  });

  final LibraryMeal meal;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final notes = (meal.notes ?? '').trim();
    return AdminListCard(
      margin: EdgeInsets.zero,
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaThumb(
              imageUrl: meal.imageUrl,
              size: 76,
              icon: Icons.restaurant_menu,
              label: 'Photo',
              onTap: meal.hasImage
                  ? () => showExerciseImageViewer(
                        context,
                        imageUrl: meal.imageUrl!.trim(),
                        title: meal.name,
                      )
                  : onEdit,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardTitle(meal.name),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusPill(
                        label: mealTypeLabel(meal.type),
                        tone: StatusPillTone.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${meal.calories} kcal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: HpColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MealMacroLine(
                    proteinG: meal.proteinG,
                    carbsG: meal.carbsG,
                    fatG: meal.fatG,
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    MetaText(notes),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "P 42g · C 60g · F 12g" with coloured dots, shared by the library and picker.
class MealMacroLine extends StatelessWidget {
  const MealMacroLine({
    super.key,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: HpColors.mutedForeground,
              ),
            ),
          ],
        );
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        item(const Color(0xFFA0D028), 'P ${proteinG}g'),
        item(const Color(0xFF38BDF8), 'C ${carbsG}g'),
        item(const Color(0xFFF59E0B), 'F ${fatG}g'),
      ],
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
          color: selected ? HpColors.primary : HpColors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? HpColors.primary : HpColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? HpColors.primaryForeground : HpColors.foreground,
          ),
        ),
      ),
    );
  }
}
