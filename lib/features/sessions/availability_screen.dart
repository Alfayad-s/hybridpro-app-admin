import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import 'session_models.dart';

const _weekdayOrder = [1, 2, 3, 4, 5, 6, 0];
const _weekdayName = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  0: 'Sunday',
};

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  var _loading = true;
  var _saving = false;
  String? _error;
  List<CoachWindow> _windows = [];
  List<CoachTimeOff> _timeOff = [];
  List<CoachSession> _upcoming = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final availability = await repo.availability();
      final upcoming = await repo.sessions(upcoming: true);
      if (!mounted) return;
      setState(() {
        _windows = availability.windows;
        _timeOff = availability.timeOff;
        _upcoming = upcoming;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await ref.read(adminRepositoryProvider).saveAvailability(
            windows: _windows,
            timeOff: _timeOff,
          );
      if (!mounted) return;
      setState(() {
        _windows = saved.windows;
        _timeOff = saved.timeOff;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hours saved')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addWindow(int weekday) async {
    var start = 6 * 60;
    var end = 10 * 60;
    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Hours on ${_weekdayName[weekday]}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: start,
                    decoration: const InputDecoration(labelText: 'From'),
                    items: [
                      for (var minute = 0; minute < 24 * 60; minute += 60)
                        DropdownMenuItem(
                          value: minute,
                          child: Text(formatHourMinute(minute)),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => start = value ?? start),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: end,
                    decoration: const InputDecoration(labelText: 'Until'),
                    items: [
                      for (var minute = 60; minute <= 24 * 60; minute += 60)
                        DropdownMenuItem(
                          value: minute,
                          child: Text(formatHourMinute(minute)),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => end = value ?? end),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    if (added != true || start >= end) {
      if (added == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The end must be after the start')),
        );
      }
      return;
    }
    setState(() {
      _windows = [
        ..._windows,
        CoachWindow(weekday: weekday, startMinute: start, endMinute: end),
      ];
    });
  }

  Future<void> _addTimeOff() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range == null) return;
    final start = DateTime.utc(range.start.year, range.start.month, range.start.day)
        .subtract(istOffset);
    final endDay = range.end.add(const Duration(days: 1));
    final end = DateTime.utc(endDay.year, endDay.month, endDay.day).subtract(istOffset);
    setState(() {
      _timeOff = [..._timeOff, CoachTimeOff(startsAt: start, endsAt: end)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HpColors.background,
      appBar: AppBar(
        title: Text('Hours', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : AppHaptics.wrap(_save),
            child: Text(_saving ? 'Saving' : 'Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(
                      'Members can book a one-hour session inside these hours.',
                      style: GoogleFonts.inter(
                        color: HpColors.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final weekday in _weekdayOrder) ...[
                      _DayHours(
                        name: _weekdayName[weekday]!,
                        windows: [
                          for (final window in _windows)
                            if (window.weekday == weekday) window,
                        ],
                        onAdd: () => _addWindow(weekday),
                        onRemove: (window) => setState(() {
                          _windows = [
                            for (final item in _windows)
                              if (item != window) item,
                          ];
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Time off',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: AppHaptics.wrap(_addTimeOff),
                          icon: const Icon(Iconsax.add, size: 18),
                          label: const Text('Block dates'),
                        ),
                      ],
                    ),
                    if (_timeOff.isEmpty)
                      Text(
                        'No blocked dates',
                        style: GoogleFonts.inter(color: HpColors.mutedForeground),
                      ),
                    for (var i = 0; i < _timeOff.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_timeOffLabel(_timeOff[i])),
                        trailing: IconButton(
                          onPressed: () => setState(() {
                            _timeOff = [
                              for (var j = 0; j < _timeOff.length; j++)
                                if (j != i) _timeOff[j],
                            ];
                          }),
                          icon: const Icon(Iconsax.trash, color: HpColors.destructive),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'This week',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_upcoming.isEmpty)
                      Text(
                        'No sessions booked',
                        style: GoogleFonts.inter(color: HpColors.mutedForeground),
                      ),
                    for (final session in _upcoming)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(session.fullName?.trim().isNotEmpty == true
                            ? session.fullName!
                            : session.email),
                        subtitle: Text(formatSessionWhen(session.startsAt)),
                      ),
                  ],
                ),
    );
  }
}

class _DayHours extends StatelessWidget {
  const _DayHours({
    required this.name,
    required this.windows,
    required this.onAdd,
    required this.onRemove,
  });

  final String name;
  final List<CoachWindow> windows;
  final VoidCallback onAdd;
  final ValueChanged<CoachWindow> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: HpColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Iconsax.add),
              ),
            ],
          ),
          if (windows.isEmpty)
            Text(
              'Closed',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: HpColors.mutedForeground,
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final window in windows)
                InputChip(
                  label: Text(
                    '${formatHourMinute(window.startMinute)} – ${formatHourMinute(window.endMinute)}',
                  ),
                  onDeleted: () => onRemove(window),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _timeOffLabel(CoachTimeOff block) {
  final start = toIst(block.startsAt);
  final end = toIst(block.endsAt).subtract(const Duration(days: 1));
  String day(DateTime value) => '${value.day}/${value.month}';
  if (start.year == end.year && start.month == end.month && start.day == end.day) {
    return day(start);
  }
  return '${day(start)} – ${day(end)}';
}
