import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/keyboard_aware_sheet.dart';

Future<Map<String, dynamic>?> showTabEditSheet(
  BuildContext context, {
  StoreTaxonomyAdmin? existing,
}) {
  return KeyboardAwareSheet.show<Map<String, dynamic>>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.72,
    builder: (ctx) => _TabEditSheet(existing: existing),
  );
}

class _TabEditSheet extends StatefulWidget {
  const _TabEditSheet({this.existing});

  final StoreTaxonomyAdmin? existing;

  @override
  State<_TabEditSheet> createState() => _TabEditSheetState();
}

class _TabEditSheetState extends State<_TabEditSheet> {
  late final TextEditingController _label;
  late final TextEditingController _slug;
  late final TextEditingController _sortOrder;
  late bool _active;
  late bool _comingSoon;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _active = e?.active ?? true;
    _comingSoon = e?.comingSoon ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _slug.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _save() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'A label is required');
      return;
    }
    final slug = _slug.text.trim().toLowerCase();
    Navigator.of(context, rootNavigator: true).pop(<String, dynamic>{
      'label': label,
      if (slug.isNotEmpty) 'slug': slug,
      'sortOrder': int.tryParse(_sortOrder.text.trim()) ?? 0,
      'active': _active,
      'comingSoon': _comingSoon,
    });
  }

  @override
  Widget build(BuildContext context) {
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
                widget.existing == null ? 'Add tab' : 'Edit tab',
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
              TextField(
                controller: _label,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Label'),
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
                decoration: const InputDecoration(labelText: 'Sort order'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible on the shop'),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Coming soon'),
                subtitle: const Text(
                  'Opens a coming soon page instead of products',
                ),
                value: _comingSoon,
                onChanged: (v) => setState(() => _comingSoon = v),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: AppHaptics.wrap(_save),
              child: Text(widget.existing == null ? 'Add' : 'Save'),
            ),
          ),
        ),
      ],
    );
  }
}
