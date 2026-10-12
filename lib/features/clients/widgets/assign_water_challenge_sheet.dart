import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/admin_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/keyboard_aware_sheet.dart';

Future<bool?> showAssignWaterChallengeSheet(
  BuildContext context, {
  required String clientId,
  AssignedWaterChallenge? existing,
}) {
  return KeyboardAwareSheet.show<bool>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.75,
    builder: (ctx) => _AssignWaterChallengeSheet(
      clientId: clientId,
      existing: existing,
    ),
  );
}

class _AssignWaterChallengeSheet extends ConsumerStatefulWidget {
  const _AssignWaterChallengeSheet({
    required this.clientId,
    this.existing,
  });

  final String clientId;
  final AssignedWaterChallenge? existing;

  @override
  ConsumerState<_AssignWaterChallengeSheet> createState() =>
      _AssignWaterChallengeSheetState();
}

class _AssignWaterChallengeSheetState
    extends ConsumerState<_AssignWaterChallengeSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _targetMl = TextEditingController();
  late int _durationDays;
  late DateTime _startDate;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title.text = e?.title ?? 'Hydration challenge';
    _description.text =
        e?.description ?? 'Hit your daily water target every day';
    _targetMl.text = '${e?.targetMlPerDay ?? 3000}';
    _durationDays = e?.durationDays ?? 7;
    _startDate = DateTime.tryParse(e?.startDate ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _targetMl.dispose();
    super.dispose();
  }

  String get _startKey {
    final y = _startDate.year.toString().padLeft(4, '0');
    final m = _startDate.month.toString().padLeft(2, '0');
    final d = _startDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final target = int.tryParse(_targetMl.text.trim()) ?? 0;
    if (target < 500) {
      setState(() => _error = 'Target must be at least 500 ml');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (_isEdit) {
        await repo.updateWaterChallenge(
          widget.clientId,
          widget.existing!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          targetMlPerDay: target,
          durationDays: _durationDays,
          startDate: _startKey,
        );
      } else {
        await repo.assignWaterChallenge(
          widget.clientId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          targetMlPerDay: target,
          durationDays: _durationDays,
          startDate: _startKey,
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
                  _isEdit ? 'Edit water challenge' : 'Assign water challenge',
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetMl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily target (ml)',
                  hintText: '3000',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Duration',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final days in [7, 14, 21, 30])
                    ChoiceChip(
                      label: Text('$days days'),
                      selected: _durationDays == days,
                      onSelected: (_) =>
                          setState(() => _durationDays = days),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(_startKey),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: AppHaptics.wrap(_pickStart),
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
              child: Text(_saving ? 'Saving…' : 'Save challenge'),
            ),
          ),
        ),
      ],
    );
  }
}
