import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/admin_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/keyboard_aware_sheet.dart';
import '../../meal_library/meal_picker_sheet.dart';

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const _dayLabels = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

Future<bool?> showAssignMealPlanSheet(
  BuildContext context, {
  required String clientId,
  AssignedMealPlan? existing,
}) {
  return KeyboardAwareSheet.show<bool>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.92,
    builder: (ctx) => _AssignMealPlanSheet(
      clientId: clientId,
      existing: existing,
    ),
  );
}

class _AssignMealPlanSheet extends ConsumerStatefulWidget {
  const _AssignMealPlanSheet({required this.clientId, this.existing});

  final String clientId;
  final AssignedMealPlan? existing;

  @override
  ConsumerState<_AssignMealPlanSheet> createState() =>
      _AssignMealPlanSheetState();
}

class _AssignMealPlanSheetState extends ConsumerState<_AssignMealPlanSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  late final List<_MealDayDraft> _days;
  int _selectedDay = 0;
  bool _saving = false;
  String? _error;
  final _picker = ImagePicker();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name.text = existing?.name ?? 'Coach meal plan';
    _description.text = existing?.description ?? '';
    _days = List.generate(7, (i) {
      final dow = i + 1;
      AssignedMealPlanDay? src;
      if (existing != null) {
        for (final d in existing.days) {
          if (d.dayOfWeek == dow) {
            src = d;
            break;
          }
        }
      }
      return _MealDayDraft(
        dayOfWeek: dow,
        meals: [
          for (final m in src?.meals ?? const <AssignedMealSlot>[])
            _MealSlotDraft.fromSlot(m),
        ],
      );
    });
    if (!_isEdit) {
      // Seed a simple weekday template the coach can edit.
      for (final dow in [1, 2, 3, 4, 5]) {
        _days[dow - 1].meals.addAll([
          _MealSlotDraft(type: 'breakfast', name: 'Oats + eggs', calories: 420),
          _MealSlotDraft(type: 'lunch', name: 'Chicken rice bowl', calories: 550),
          _MealSlotDraft(type: 'dinner', name: 'Fish + veggies', calories: 480),
        ]);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final d in _days) {
      for (final m in d.meals) {
        m.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final mealCount = _days.fold<int>(0, (n, d) => n + d.meals.length);
    if (mealCount == 0) {
      setState(() => _error = 'Add at least one meal');
      return;
    }
    if (_days.any((d) => d.meals.any((m) => m.uploading))) {
      setState(() => _error = 'Wait for meal photos to finish uploading');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final days = [
      for (final d in _days)
        {
          'dayOfWeek': d.dayOfWeek,
          'meals': [
            for (final m in d.meals)
              if (m.name.text.trim().isNotEmpty)
                {
                  'type': m.type,
                  'name': m.name.text.trim(),
                  'calories': int.tryParse(m.calories.text.trim()) ?? 0,
                  'proteinG': int.tryParse(m.protein.text.trim()) ?? 0,
                  'carbsG': int.tryParse(m.carbs.text.trim()) ?? 0,
                  'fatG': int.tryParse(m.fat.text.trim()) ?? 0,
                  if (m.notes.text.trim().isNotEmpty)
                    'notes': m.notes.text.trim(),
                  if (m.imageUrl != null) 'imageUrl': m.imageUrl,
                },
          ],
        },
    ];
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (_isEdit) {
        await repo.updateMealPlan(
          widget.clientId,
          widget.existing!.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          days: days,
        );
      } else {
        await repo.assignMealPlan(
          widget.clientId,
          name: _name.text.trim(),
          description: _description.text.trim(),
          days: days,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  void _addMeal() {
    setState(() {
      _days[_selectedDay].meals.add(
            _MealSlotDraft(type: 'snack', name: '', calories: 200),
          );
    });
  }

  Future<void> _addFromLibrary() async {
    final dayIndex = _selectedDay;
    final picked = await showMealPickerSheet(
      context,
      dayLabel: _dayLabels[dayIndex + 1],
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _error = null;
      _days[dayIndex].meals.addAll([
        for (final m in picked)
          _MealSlotDraft(
            type: _mealTypes.contains(m.type) ? m.type : 'snack',
            name: m.name,
            calories: m.calories,
            proteinG: m.proteinG,
            carbsG: m.carbsG,
            fatG: m.fatG,
            notes: m.notes ?? '',
            imageUrl: m.hasImage ? m.imageUrl!.trim() : null,
          ),
      ]);
    });
  }

  Future<void> _pickPhoto(_MealSlotDraft meal) async {
    if (meal.uploading) return;
    AppHaptics.selection();
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1400,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the photo library');
      return;
    }
    if (file == null || !mounted) return;
    setState(() {
      meal.uploading = true;
      _error = null;
    });
    try {
      final url = await ref.read(adminRepositoryProvider).uploadExerciseMedia(
            filePath: file.path,
            filename: file.name,
            kind: 'image',
            exerciseKey: 'meal-${DateTime.now().millisecondsSinceEpoch}',
          );
      if (!mounted) return;
      setState(() {
        meal.imageUrl = url;
        meal.uploading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        meal.uploading = false;
        _error = e.message;
      });
    }
  }

  void _removePhoto(_MealSlotDraft meal) {
    AppHaptics.selection();
    setState(() => meal.imageUrl = null);
  }

  void _removeMeal(int index) {
    setState(() {
      final meal = _days[_selectedDay].meals.removeAt(index);
      meal.dispose();
    });
  }

  void _copyToWeekdays() {
    final src = _days[_selectedDay];
    setState(() {
      for (var i = 0; i < 5; i++) {
        if (i == _selectedDay) continue;
        for (final m in _days[i].meals) {
          m.dispose();
        }
        _days[i].meals
          ..clear()
          ..addAll(src.meals.map((m) => m.clone()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final day = _days[_selectedDay];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit ? 'Edit meal plan' : 'Assign meal plan',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Plan name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final selected = i == _selectedDay;
                    final count = _days[i].meals.length;
                    return ChoiceChip(
                      label: Text(
                        '${_dayLabels[i + 1]}${count > 0 ? ' · $count' : ''}',
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedDay = i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SheetAction(
                      icon: Icons.menu_book_outlined,
                      label: 'From library',
                      primary: true,
                      onTap: _addFromLibrary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SheetAction(
                      icon: Icons.add,
                      label: 'Custom meal',
                      onTap: _addMeal,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: AppHaptics.wrap(_copyToWeekdays),
                  child: const Text('Copy day → weekdays'),
                ),
              ),
              const SizedBox(height: 8),
              if (day.meals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No meals for ${_dayLabels[day.dayOfWeek]}',
                    style: GoogleFonts.inter(color: HpColors.mutedForeground),
                  ),
                )
              else
                for (var i = 0; i < day.meals.length; i++)
                  _MealSlotCard(
                    meal: day.meals[i],
                    onRemove: () => _removeMeal(i),
                    onTypeChanged: (t) => setState(() => day.meals[i].type = t),
                    onPickPhoto: () => _pickPhoto(day.meals[i]),
                    onRemovePhoto: () => _removePhoto(day.meals[i]),
                  ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.inter(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: _saving ? null : AppHaptics.wrap(_save),
              child: Text(_saving ? 'Saving…' : 'Save meal plan'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealDayDraft {
  _MealDayDraft({required this.dayOfWeek, List<_MealSlotDraft>? meals})
      : meals = meals ?? [];

  final int dayOfWeek;
  final List<_MealSlotDraft> meals;
}

class _MealSlotDraft {
  _MealSlotDraft({
    required this.type,
    required String name,
    required int calories,
    int proteinG = 0,
    int carbsG = 0,
    int fatG = 0,
    String notes = '',
    this.imageUrl,
  })  : name = TextEditingController(text: name),
        calories = TextEditingController(text: '$calories'),
        protein = TextEditingController(text: '$proteinG'),
        carbs = TextEditingController(text: '$carbsG'),
        fat = TextEditingController(text: '$fatG'),
        notes = TextEditingController(text: notes);

  factory _MealSlotDraft.fromSlot(AssignedMealSlot m) {
    return _MealSlotDraft(
      type: m.type,
      name: m.name,
      calories: m.calories,
      proteinG: m.proteinG,
      carbsG: m.carbsG,
      fatG: m.fatG,
      notes: m.notes ?? '',
      imageUrl: m.hasImage ? m.imageUrl!.trim() : null,
    );
  }

  String type;
  String? imageUrl;
  bool uploading = false;
  final TextEditingController name;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;
  final TextEditingController notes;

  _MealSlotDraft clone() => _MealSlotDraft(
        type: type,
        name: name.text,
        calories: int.tryParse(calories.text) ?? 0,
        proteinG: int.tryParse(protein.text) ?? 0,
        carbsG: int.tryParse(carbs.text) ?? 0,
        fatG: int.tryParse(fat.text) ?? 0,
        notes: notes.text,
        imageUrl: imageUrl,
      );

  void dispose() {
    name.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    notes.dispose();
  }
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.meal,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  final _MealSlotDraft meal;
  final VoidCallback onRemove;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HpColors.subtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealPhotoTile(
                imageUrl: meal.imageUrl,
                uploading: meal.uploading,
                onPick: onPickPhoto,
                onRemove: onRemovePhoto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('type-${meal.type}-${meal.hashCode}'),
                            initialValue: meal.type,
                            isDense: true,
                            decoration: const InputDecoration(labelText: 'Type'),
                            items: [
                              for (final t in _mealTypes)
                                DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    '${t[0].toUpperCase()}${t.substring(1)}',
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) onTypeChanged(v);
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove meal',
                          onPressed: onRemove,
                          color: HpColors.mutedForeground,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: meal.name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Food name'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: meal.calories,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: meal.protein,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'P'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: meal.carbs,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'C'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: meal.fat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'F'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? HpColors.primaryForeground : HpColors.foreground;
    return Material(
      color: primary ? HpColors.primary : HpColors.subtle,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary ? HpColors.primary : HpColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealPhotoTile extends StatelessWidget {
  const _MealPhotoTile({
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  static const double _size = 104;

  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: HpColors.card,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: uploading ? null : onPick,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasImage
                          ? HpColors.border
                          : HpColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _PhotoPlaceholder(
                                label: 'Retry photo',
                              ),
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                color: const Color(0x990B0B0F),
                                child: Text(
                                  'Change',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const _PhotoPlaceholder(label: 'Add photo'),
                ),
              ),
            ),
          ),
          if (uploading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: const ColoredBox(
                  color: Color(0xB30B0B0F),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
              ),
            ),
          if (hasImage && !uploading)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: HpColors.destructive,
                    shape: BoxShape.circle,
                    border: Border.all(color: HpColors.subtle, width: 2),
                  ),
                  child: const Icon(Icons.close, size: 13, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: HpColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_a_photo_outlined,
            size: 17,
            color: HpColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: HpColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
