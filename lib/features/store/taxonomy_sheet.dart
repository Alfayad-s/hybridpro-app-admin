import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/hold_button.dart';
import '../../widgets/keyboard_aware_sheet.dart';

Future<void> showStoreTaxonomySheet(BuildContext context) {
  return KeyboardAwareSheet.show<void>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.9,
    builder: (ctx) => const _TaxonomySheet(),
  );
}

class _TaxonomySheet extends ConsumerStatefulWidget {
  const _TaxonomySheet();

  @override
  ConsumerState<_TaxonomySheet> createState() => _TaxonomySheetState();
}

class _TaxonomySheetState extends ConsumerState<_TaxonomySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Categories & kinds',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: HpColors.foreground,
          unselectedLabelColor: HpColors.mutedForeground,
          indicatorColor: HpColors.primary,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Kinds'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _TaxonomyList(
                kind: _TaxonomyType.category,
                provider: storeCategoriesProvider,
              ),
              _TaxonomyList(
                kind: _TaxonomyType.kind,
                provider: storeKindsProvider,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _TaxonomyType { category, kind }

class _TaxonomyList extends ConsumerWidget {
  const _TaxonomyList({required this.kind, required this.provider});

  final _TaxonomyType kind;
  final FutureProvider<List<StoreTaxonomyAdmin>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final items = async.asData?.value ?? const <StoreTaxonomyAdmin>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: AppHaptics.wrap(() => _edit(context, ref)),
              icon: const Icon(Icons.add, size: 18),
              label: Text(kind == _TaxonomyType.category ? 'Add category' : 'Add kind'),
            ),
          ),
        ),
        Expanded(
          child: async.isLoading && async.asData == null
              ? const Center(child: CircularProgressIndicator())
              : async.hasError && async.asData == null
                  ? Center(
                      child: TextButton(
                        onPressed: () => ref.refresh(provider.future),
                        child: const Text('Retry'),
                      ),
                    )
                  : items.isEmpty
                      ? Center(
                          child: Text(
                            'Nothing yet',
                            style: GoogleFonts.inter(
                              color: HpColors.mutedForeground,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref.refresh(provider.future),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final item = items[i];
                              return Material(
                                color: HpColors.subtle,
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  onTap: AppHaptics.wrap(
                                    () => _edit(context, ref, item),
                                  ),
                                  title: Text(
                                    item.label,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      item.slug,
                                      'sort ${item.sortOrder}',
                                      if (!item.active) 'hidden',
                                    ].join(' · '),
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Iconsax.trash, size: 18),
                                    onPressed: AppHaptics.wrap(
                                      () => _delete(context, ref, item),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    StoreTaxonomyAdmin? existing,
  ]) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _TaxonomyEditDialog(
        title: existing == null
            ? (kind == _TaxonomyType.category ? 'Add category' : 'Add kind')
            : (kind == _TaxonomyType.category ? 'Edit category' : 'Edit kind'),
        existing: existing,
      ),
    );
    if (body == null || !context.mounted) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (kind == _TaxonomyType.category) {
        if (existing == null) {
          await repo.createProductCategory(body);
        } else {
          await repo.updateProductCategory(existing.id, body);
        }
        await ref.refresh(storeCategoriesProvider.future);
      } else {
        if (existing == null) {
          await repo.createProductKind(body);
        } else {
          await repo.updateProductKind(existing.id, body);
        }
        await ref.refresh(storeKindsProvider.future);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save. $e')),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    StoreTaxonomyAdmin item,
  ) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: kind == _TaxonomyType.category
          ? 'Delete category?'
          : 'Delete kind?',
      message: item.label,
    );
    if (!ok) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (kind == _TaxonomyType.category) {
        await repo.deleteProductCategory(item.id);
        await ref.refresh(storeCategoriesProvider.future);
      } else {
        await repo.deleteProductKind(item.id);
        await ref.refresh(storeKindsProvider.future);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _TaxonomyEditDialog extends StatefulWidget {
  const _TaxonomyEditDialog({required this.title, this.existing});

  final String title;
  final StoreTaxonomyAdmin? existing;

  @override
  State<_TaxonomyEditDialog> createState() => _TaxonomyEditDialogState();
}

class _TaxonomyEditDialogState extends State<_TaxonomyEditDialog> {
  late final TextEditingController _label;
  late final TextEditingController _slug;
  late final TextEditingController _sortOrder;
  late bool _active;
  String? _error;

  String _slugFromLabel(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    _slug.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _slug,
              decoration: const InputDecoration(
                labelText: 'Slug (optional)',
                hintText: 'auto from label',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sort order',
                helperText: 'Lower shows first (Plans = 0)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final label = _label.text.trim();
            if (label.isEmpty) {
              setState(() => _error = 'A label is required');
              return;
            }
            final typed = _slug.text.trim().toLowerCase();
            final slug = typed.isEmpty ? _slugFromLabel(label) : typed;
            if (slug.isEmpty) {
              setState(() => _error = 'Use a label with letters or numbers');
              return;
            }
            Navigator.of(context, rootNavigator: true).pop(<String, dynamic>{
              'label': label,
              'slug': slug,
              'sortOrder': int.tryParse(_sortOrder.text.trim()) ?? 0,
              'active': _active,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
