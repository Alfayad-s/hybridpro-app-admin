import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/admin_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../sessions/session_models.dart';

class ClientSessionsSection extends ConsumerStatefulWidget {
  const ClientSessionsSection({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientSessionsSection> createState() =>
      _ClientSessionsSectionState();
}

class _ClientSessionsSectionState extends ConsumerState<ClientSessionsSection> {
  var _loading = true;
  String? _error;
  List<CoachSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await ref
          .read(adminRepositoryProvider)
          .sessions(clientId: widget.clientId);
      if (!mounted) return;
      setState(() {
        _sessions = sessions.where((session) => session.upcoming).toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Could not load sessions. Update the live API, then try again.'
            : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _book() async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HpColors.card,
      builder: (context) => _BookSessionSheet(clientId: widget.clientId),
    );
    if (booked == true) _load();
  }

  Future<void> _cancel(CoachSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel session?'),
        content: Text(formatSessionWhen(session.startsAt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).cancelSession(session.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: AppHaptics.wrap(_book),
            child: const Text('Book session'),
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else if (_error != null)
          Text(
            _error!,
            style: GoogleFonts.inter(color: HpColors.destructive, fontSize: 13),
          )
        else if (_sessions.isEmpty)
          Text(
            'No upcoming sessions',
            style: GoogleFonts.inter(color: HpColors.mutedForeground),
          )
        else
          for (final session in _sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatSessionWhen(session.startsAt)),
              subtitle: Text(
                session.bookedBy == 'coach' ? 'Booked by you' : 'Booked by member',
              ),
              trailing: TextButton(
                onPressed: () => _cancel(session),
                child: const Text('Cancel'),
              ),
            ),
      ],
    );
  }
}

class _BookSessionSheet extends ConsumerStatefulWidget {
  const _BookSessionSheet({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_BookSessionSheet> createState() => _BookSessionSheetState();
}

class _BookSessionSheetState extends ConsumerState<_BookSessionSheet> {
  var _loading = true;
  String? _error;
  List<SessionSlot> _slots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final slots = await ref.read(adminRepositoryProvider).sessionSlots();
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Could not load open times. Update the live API, then try again.'
            : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _book(SessionSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book this hour?'),
        content: Text(formatSessionWhen(slot.startsAt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Book'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(adminRepositoryProvider).bookClientSession(
            clientId: widget.clientId,
            startsAt: slot.startsAt,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final groups = <String, List<SessionSlot>>{};
    for (final slot in _slots) {
      groups.putIfAbsent(istDayKey(slot.startsAt), () => []).add(slot);
    }
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open hours',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _slots.isEmpty
                          ? const Center(child: Text('No open hours in the next 14 days'))
                          : ListView(
                              children: [
                                for (final entry in groups.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                                    child: Text(
                                      istDayLabel(entry.value.first.startsAt),
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final slot in entry.value)
                                        ActionChip(
                                          label: Text(_hourOnly(slot.startsAt)),
                                          onPressed: () => _book(slot),
                                        ),
                                    ],
                                  ),
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

String _hourOnly(DateTime instant) {
  final ist = toIst(instant);
  final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
  final suffix = ist.hour < 12 ? 'AM' : 'PM';
  return '$hour:00 $suffix';
}
