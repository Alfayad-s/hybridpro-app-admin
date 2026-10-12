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

Future<Map<String, dynamic>?> showProductEditSheet(
  BuildContext context, {
  required WidgetRef ref,
  StoreProductAdmin? existing,
}) {
  return KeyboardAwareSheet.show<Map<String, dynamic>>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.88,
    builder: (ctx) => _ProductEditSheet(ref: ref, existing: existing),
  );
}

class _ProductEditSheet extends ConsumerStatefulWidget {
  const _ProductEditSheet({required this.ref, this.existing});

  final WidgetRef ref;
  final StoreProductAdmin? existing;

  @override
  ConsumerState<_ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends ConsumerState<_ProductEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _subtitle;
  late final TextEditingController _description;
  late final TextEditingController _priceLabel;
  late final TextEditingController _pricePaise;
  late final TextEditingController _sizes;
  late final TextEditingController _sortOrder;

  late String _category;
  late String _kind;
  late String? _planId;
  late bool _active;
  late bool _comingSoon;
  late String? _imageUrl;
  String? _uploading;
  String? _error;
  bool _saving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _subtitle = TextEditingController(text: e?.subtitle ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _priceLabel = TextEditingController(text: e?.priceLabel ?? '');
    _pricePaise = TextEditingController(
      text: e?.pricePaise != null ? '${e!.pricePaise}' : '',
    );
    _sizes = TextEditingController(text: e?.sizes.join(', ') ?? '');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _category = e?.category ?? 'plans';
    _kind = e?.kind ?? 'plan';
    _planId = e?.planId;
    _active = e?.active ?? true;
    _comingSoon = e?.comingSoon ?? false;
    _imageUrl = e?.imageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _subtitle.dispose();
    _description.dispose();
    _priceLabel.dispose();
    _pricePaise.dispose();
    _sizes.dispose();
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

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final priceLabel = _priceLabel.text.trim();
    if (title.isEmpty || priceLabel.isEmpty) {
      setState(() => _error = 'Title and price are required');
      return;
    }
    if (_kind == 'plan' && (_planId == null || _planId!.isEmpty)) {
      setState(() => _error = 'Pick a planId for plan products');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final paiseRaw = _pricePaise.text.trim();
    final body = <String, dynamic>{
      'title': title,
      if (_slug.text.trim().isNotEmpty) 'slug': _slug.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      'category': _category,
      'kind': _kind,
      'priceLabel': priceLabel,
      'pricePaise': paiseRaw.isEmpty ? null : int.tryParse(paiseRaw),
      'imageUrl': _imageUrl,
      'sizes': _sizes.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'planId': _kind == 'plan' ? _planId : null,
      'active': _active,
      'comingSoon': _comingSoon,
      'sortOrder': int.tryParse(_sortOrder.text.trim()) ?? 0,
    };

    Navigator.of(context).pop(body);
  }

  bool get _networkImage {
    final url = _imageUrl?.trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String _pickSlug(
    List<StoreTaxonomyAdmin> items,
    String preferred,
    String fallback,
  ) {
    if (items.any((e) => e.slug == preferred)) return preferred;
    if (items.isNotEmpty) return items.first.slug;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(storeCategoriesProvider);
    final kindsAsync = ref.watch(storeKindsProvider);
    final categories = (categoriesAsync.asData?.value ?? const [])
        .where((c) => c.active || c.slug == _category)
        .toList();
    final kinds = (kindsAsync.asData?.value ?? const [])
        .where((k) => k.active || k.slug == _kind)
        .toList();

    // Keep selection valid once lists load (plans first from API sort).
    if (categories.isNotEmpty &&
        !categories.any((c) => c.slug == _category)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _category = _pickSlug(categories, 'plans', categories.first.slug);
          if (_category == 'plans') {
            _kind = 'plan';
          }
        });
      });
    }
    if (kinds.isNotEmpty && !kinds.any((k) => k.slug == _kind)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _kind = _pickSlug(kinds, 'plan', kinds.first.slug);
          if (_kind != 'plan') _planId = null;
        });
      });
    }

    final categoryValue =
        categories.any((c) => c.slug == _category) ? _category : null;
    final kindValue = kinds.any((k) => k.slug == _kind) ? _kind : null;
    final taxonomyLoading =
        (categoriesAsync.isLoading && categories.isEmpty) ||
            (kindsAsync.isLoading && kinds.isEmpty);

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
                widget.existing == null ? 'Add product' : 'Edit product',
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
                aspectRatio: 1.4,
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
                                        ? 'Bundled asset — tap to replace'
                                        : 'Tap to upload image',
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
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Slug (optional)',
                  hintText: 'auto from title',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: 'Subtitle'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              if (taxonomyLoading)
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('category-$categoryValue'),
                        initialValue: categoryValue,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: [
                          for (final c in categories)
                            DropdownMenuItem(
                              value: c.slug,
                              child: Text(c.label),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _category = v;
                            if (v == 'plans') {
                              _kind = 'plan';
                            } else if (_kind == 'plan') {
                              _kind = 'merch';
                              _planId = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('kind-$kindValue'),
                        initialValue: kindValue,
                        decoration: const InputDecoration(labelText: 'Kind'),
                        items: [
                          for (final k in kinds)
                            DropdownMenuItem(
                              value: k.slug,
                              child: Text(k.label),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _kind = v;
                            if (v != 'plan') _planId = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              if (_kind == 'plan') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('plan-$_planId'),
                  initialValue: _planId,
                  decoration: const InputDecoration(labelText: 'Plan ID'),
                  items: [
                    for (final id in planIds)
                      DropdownMenuItem(value: id, child: Text(id)),
                  ],
                  onChanged: (v) => setState(() => _planId = v),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _priceLabel,
                decoration: const InputDecoration(
                  labelText: 'Price label',
                  hintText: '₹1,499',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pricePaise,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (paise, optional)',
                  hintText: '149900',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _sizes,
                decoration: const InputDecoration(
                  labelText: 'Sizes (comma separated)',
                  hintText: 'S, M, L, XL',
                ),
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
                  'Active in member store',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Coming soon',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Shows a tag and cannot be bought'),
                value: _comingSoon,
                onChanged: (v) => setState(() => _comingSoon = v),
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
              onPressed: _saving || taxonomyLoading
                  ? null
                  : AppHaptics.wrap(_save),
              child: Text(_saving ? 'Saving…' : 'Save product'),
            ),
          ),
        ),
      ],
    );
  }
}
