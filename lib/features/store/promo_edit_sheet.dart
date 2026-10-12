import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/keyboard_aware_sheet.dart';

Future<Map<String, dynamic>?> showPromoEditSheet(
  BuildContext context, {
  required WidgetRef ref,
  required String placement,
  ShopPromoAdmin? existing,
}) {
  return KeyboardAwareSheet.show<Map<String, dynamic>>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.88,
    builder: (ctx) => _PromoEditSheet(
      ref: ref,
      placement: placement,
      existing: existing,
    ),
  );
}

class _PromoEditSheet extends ConsumerStatefulWidget {
  const _PromoEditSheet({
    required this.ref,
    required this.placement,
    this.existing,
  });

  final WidgetRef ref;
  final String placement;
  final ShopPromoAdmin? existing;

  @override
  ConsumerState<_PromoEditSheet> createState() => _PromoEditSheetState();
}

class _PromoEditSheetState extends ConsumerState<_PromoEditSheet> {
  late final TextEditingController _alt;
  late final TextEditingController _label;
  late final TextEditingController _sortOrder;

  late String _category;
  late bool _active;
  late String? _imageUrl;
  String? _uploading;
  String? _error;
  bool _saving = false;
  final _picker = ImagePicker();

  bool get _isBanner => widget.placement == 'banner';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _alt = TextEditingController(text: e?.alt ?? '');
    _label = TextEditingController(text: e?.label ?? '');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _category = e?.category ?? '';
    _active = e?.active ?? true;
    _imageUrl = e?.imageUrl;
  }

  @override
  void dispose() {
    _alt.dispose();
    _label.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    AppHaptics.selection();
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    setState(() {
      _uploading = 'image';
      _error = null;
    });
    try {
      final url = await widget.ref.read(adminRepositoryProvider).uploadProductMedia(
            filePath: file.path,
            filename: file.name,
          );
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploading = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = null;
        _error = e.message;
      });
    }
  }

  void _save() {
    if (_saving) return;
    final alt = _alt.text.trim();
    final image = _imageUrl?.trim() ?? '';
    if (image.isEmpty) {
      setState(() => _error = 'Upload an image');
      return;
    }
    if (alt.isEmpty) {
      setState(() => _error = 'Alt text is required');
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'placement': widget.placement,
      'imageUrl': image,
      'alt': alt,
      'label': _isBanner ? _label.text.trim() : '',
      'category': _category,
      'active': _active,
      'sortOrder': int.tryParse(_sortOrder.text.trim()) ?? 0,
    });
  }

  bool get _networkImage {
    final url = _imageUrl?.trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(storeCategoriesProvider);
    final categories = (categoriesAsync.asData?.value ?? const <StoreTaxonomyAdmin>[])
        .where((c) => c.active || c.slug == _category)
        .toList();
    final categoryValue = _category.isEmpty
        ? ''
        : categories.any((c) => c.slug == _category)
            ? _category
            : '';
    final loading = categoriesAsync.isLoading && categories.isEmpty;
    final title = _isBanner
        ? (widget.existing == null ? 'Add banner' : 'Edit banner')
        : (widget.existing == null ? 'Add card promo' : 'Edit card promo');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HpColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HpColors.foreground,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            children: [
              AspectRatio(
                aspectRatio: _isBanner ? 1.8 : 1,
                child: Material(
                  color: HpColors.subtle,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _uploading != null ? null : _pickImage,
                    child: _uploading != null
                        ? const Center(child: CircularProgressIndicator())
                        : _networkImage
                            ? Image.network(_imageUrl!, fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Iconsax.gallery_add, size: 28),
                                  const SizedBox(height: 8),
                                  Text(
                                    _imageUrl != null && _imageUrl!.isNotEmpty
                                        ? 'Current shop image — tap to replace'
                                        : 'Tap to upload image',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: HpColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _alt,
                decoration: const InputDecoration(labelText: 'Alt text'),
              ),
              if (_isBanner) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
              ],
              const SizedBox(height: 10),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('promo-category-$categoryValue'),
                  initialValue: categoryValue,
                  decoration: const InputDecoration(
                    labelText: 'Category on tap',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    for (final c in categories)
                      DropdownMenuItem(value: c.slug, child: Text(c.label)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _category = v);
                  },
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _sortOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Visible on the shop',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
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
              onPressed: _saving || loading ? null : AppHaptics.wrap(_save),
              child: Text(widget.existing == null ? 'Add' : 'Save'),
            ),
          ),
        ),
      ],
    );
  }
}
