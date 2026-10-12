import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/admin_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';

class CoachDeskSection extends ConsumerStatefulWidget {
  const CoachDeskSection({
    super.key,
    required this.clientId,
    required this.notes,
    required this.checkins,
    required this.onChanged,
  });

  final String clientId;
  final String notes;
  final List<Checkin> checkins;
  final VoidCallback onChanged;

  @override
  ConsumerState<CoachDeskSection> createState() => _CoachDeskSectionState();
}

class _CoachDeskSectionState extends ConsumerState<CoachDeskSection> {
  late final TextEditingController _notes;
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.notes);
  }

  @override
  void didUpdateWidget(covariant CoachDeskSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notes != widget.notes && _notes.text != widget.notes) {
      _notes.text = widget.notes;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    try {
      await ref.read(adminRepositoryProvider).patchClient(
            widget.clientId,
            action: 'save_notes',
            notes: _notes.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
      widget.onChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  Future<void> _addCheckin() async {
    final weight = TextEditingController();
    final adherence = TextEditingController();
    final update = TextEditingController();
    final reply = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add check-in', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: weight, decoration: const InputDecoration(labelText: 'Weight')),
            TextField(
              controller: adherence,
              decoration: const InputDecoration(labelText: 'Adherence'),
            ),
            TextField(
              controller: update,
              decoration: const InputDecoration(labelText: 'Client update'),
              maxLines: 2,
            ),
            TextField(
              controller: reply,
              decoration: const InputDecoration(labelText: 'Coach reply'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, true)),
              child: const Text('Save check-in'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      weight.dispose();
      adherence.dispose();
      update.dispose();
      reply.dispose();
      return;
    }
    try {
      await ref.read(adminRepositoryProvider).addCheckin(
            widget.clientId,
            weight: weight.text,
            adherence: adherence.text,
            clientUpdate: update.text,
            coachReply: reply.text,
          );
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      weight.dispose();
      adherence.dispose();
      update.dispose();
      reply.dispose();
    }
  }

  Future<void> _reply(Checkin checkin) async {
    final reply = TextEditingController(text: checkin.coachReply ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coach reply'),
        content: TextField(controller: reply, maxLines: 4),
        actions: [
          TextButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, false)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, true)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) {
      reply.dispose();
      return;
    }
    try {
      await ref.read(adminRepositoryProvider).replyCheckin(
            widget.clientId,
            checkin.id,
            coachReply: reply.text,
          );
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      reply.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _notes,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Private notes',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: AppHaptics.wrap(_savingNotes ? null : _saveNotes),
          child: Text(_savingNotes ? 'Saving…' : 'Save notes'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Check-ins', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: AppHaptics.wrap(_addCheckin),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (widget.checkins.isEmpty)
          const Text('No check-ins yet')
        else
          ...widget.checkins.map(
            (c) => Card(
              child: ListTile(
                title: Text(formatDate(c.checkinDate)),
                subtitle: Text(
                  [
                    if (c.weight != null && c.weight!.isNotEmpty) 'Wt ${c.weight}',
                    if (c.adherence != null && c.adherence!.isNotEmpty) c.adherence!,
                    if (c.clientUpdate != null && c.clientUpdate!.isNotEmpty) c.clientUpdate!,
                    if (c.coachReply != null && c.coachReply!.isNotEmpty)
                      'Reply: ${c.coachReply}',
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.reply),
                  onPressed: AppHaptics.wrap(() => _reply(c)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
