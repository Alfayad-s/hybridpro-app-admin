import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/keyboard_aware_sheet.dart';

const mealLibraryTypes = <(String, String)>[
  ('breakfast', 'Breakfast'),
  ('lunch', 'Lunch'),
  ('dinner', 'Dinner'),
  ('snack', 'Snack'),
];

String mealTypeLabel(String type) {
  for (final (value, label) in mealLibraryTypes) {
    if (value == type) return label;
  }
  return type.isEmpty ? 'Meal' : '${type[0].toUpperCase()}${type.substring(1)}';
}

/// Returns the create/update body, or null when dismissed.
Future<Map<String, dynamic>?> showMealEditSheet(
  BuildContext context, {
  LibraryMeal? existing,
}) {
  return KeyboardAwareSheet.show<Map<String, dynamic>>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.9,
    builder: (ctx) => _MealEditSheet(existing: existing),
  );
}

class _MealEditSheet extends ConsumerStatefulWidget {
  const _MealEditSheet({this.existing});

  final LibraryMeal? existing;

  @override
  ConsumerState<_MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends ConsumerState<_MealEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _notes;
  late String _type;
  String? _imageUrl;
  bool _uploading = false;
  String? _error;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _calories = TextEditingController(text: m == null ? '' : '${m.calories}');
    _protein = TextEditingController(text: m == null ? '' : '${m.proteinG}');
    _carbs = TextEditingController(text: m == null ? '' : '${m.carbsG}');
    _fat = TextEditingController(text: m == null ? '' : '${m.fatG}');
    _notes = TextEditingController(text: m?.notes ?? '');
    _type = m?.type ?? 'lunch';
    _imageUrl = m?.hasImage == true ? m!.imageUrl!.trim() : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_uploading) return;
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
      _uploading = true;
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
        _imageUrl = url;
        _uploading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.message;
      });
    }
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the meal a name');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'name': name,
      'type': _type,
      'calories': _int(_calories),
      'proteinG': _int(_protein),
      'carbsG': _int(_carbs),
      'fatG': _int(_fat),
      'notes': _notes.text.trim(),
      'imageUrl': _imageUrl,
    });
  }

  InputDecoration _field(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _numberField(TextEditingController c, String label, String suffix) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.next,
      decoration: _field(label, suffix: suffix),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  widget.existing == null ? 'New meal' : 'Edit meal',
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
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + media.viewInsets.bottom),
            children: [
              _PhotoPicker(
                imageUrl: _imageUrl,
                uploading: _uploading,
                onPick: _pickPhoto,
                onRemove: () {
                  AppHaptics.selection();
                  setState(() => _imageUrl = null);
                },
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: _field('Meal name'),
              ),
              const SizedBox(height: 16),
              const _Label('Meal type'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < mealLibraryTypes.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _TypeChip(
                        label: mealLibraryTypes[i].$2,
                        selected: _type == mealLibraryTypes[i].$1,
                        onTap: () =>
                            setState(() => _type = mealLibraryTypes[i].$1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              const _Label('Nutrition'),
              const SizedBox(height: 8),
              _numberField(_calories, 'Calories', 'kcal'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numberField(_protein, 'Protein', 'g')),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_carbs, 'Carbs', 'g')),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_fat, 'Fat', 'g')),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: _field('Notes / recipe (optional)'),
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
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + media.padding.bottom),
          decoration: const BoxDecoration(
            color: HpColors.card,
            border: Border(top: BorderSide(color: HpColors.border)),
          ),
          child: FilledButton(
            onPressed: _uploading ? null : AppHaptics.wrap(_save),
            child: Text(_uploading ? 'Uploading photo…' : 'Save meal'),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
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
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? HpColors.primary : HpColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? HpColors.primary : HpColors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: HpColors.subtle,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: uploading ? null : onPick,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _PhotoEmpty(),
                )
              else
                const _PhotoEmpty(),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasImage
                        ? HpColors.border
                        : HpColors.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
              if (hasImage && !uploading)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Row(
                    children: [
                      _PhotoAction(
                        icon: Iconsax.camera,
                        label: 'Change',
                        onTap: onPick,
                      ),
                      const SizedBox(width: 8),
                      _PhotoAction(
                        icon: Iconsax.trash,
                        label: 'Remove',
                        color: HpColors.destructive,
                        onTap: onRemove,
                      ),
                    ],
                  ),
                ),
              if (uploading)
                const ColoredBox(
                  color: Color(0xB30B0B0F),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoEmpty extends StatelessWidget {
  const _PhotoEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: HpColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_a_photo_outlined,
            color: HpColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Add meal photo',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: HpColors.foreground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'JPG, PNG or WEBP · max 5MB',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: HpColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC0B0B0F),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
