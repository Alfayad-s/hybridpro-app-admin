import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/common.dart';
import '../../widgets/hold_button.dart';
import '../../widgets/list_cards.dart';
import '../../widgets/profile_photo.dart';
import 'widgets/assign_meal_plan_sheet.dart';
import 'widgets/assign_water_challenge_sheet.dart';
import 'widgets/assign_workout_sheet.dart';
import 'widgets/assigned_plan_card.dart';
import 'widgets/client_detail_cards.dart';
import 'widgets/meal_plan_view.dart';
import 'widgets/coach_desk_section.dart';
import 'widgets/client_sessions_section.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  bool _loading = true;
  String? _error;
  ClientDetail? _detail;

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
      final detail =
          await ref.read(adminRepositoryProvider).clientDetail(widget.clientId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _action(String action, {int? days, String? planId}) async {
    try {
      await ref.read(adminRepositoryProvider).patchClient(
            widget.clientId,
            action: action,
            days: days,
            planId: planId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ($action)')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _extend() async {
    final daysCtrl = TextEditingController(text: '30');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extend access'),
        content: TextField(
          controller: daysCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Days'),
        ),
        actions: [
          TextButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, false)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, true)),
            child: const Text('Extend'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _action('extend', days: int.tryParse(daysCtrl.text) ?? 30);
    daysCtrl.dispose();
  }

  Future<void> _changePlan() async {
    var planId = _detail?.subscription.planId ?? 'performance';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change plan'),
        content: DropdownButtonFormField<String>(
          initialValue: planId,
          items: planIds
              .map((p) => DropdownMenuItem(value: p, child: Text(planLabel(p))))
              .toList(),
          onChanged: AppHaptics.wrapChanged((v) => planId = v ?? planId),
        ),
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
    if (ok != true) return;
    await _action('change_plan', planId: planId);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text('This marks the client subscription as cancelled.'),
        actions: [
          TextButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, false)),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, true)),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (ok == true) await _action('cancel');
  }

  Future<void> _unassignPlan(AssignedPlan p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Unassign plan?',
      message: 'Hold to remove "${p.name}" from this client’s app.',
      holdLabel: 'Hold to unassign',
      doneLabel: 'Unassigned',
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .unassignWorkout(widget.clientId, p.id);
      if (!mounted) return;
      _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _unassignMealPlan(AssignedMealPlan p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Unassign meal plan?',
      message: 'Hold to remove "${p.name}" from this client’s app.',
      holdLabel: 'Hold to unassign',
      doneLabel: 'Unassigned',
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .unassignMealPlan(widget.clientId, p.id);
      if (!mounted) return;
      _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeWaterChallenge(AssignedWaterChallenge c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Remove water challenge?',
      message: 'Hold to remove "${c.title}" from this client’s app.',
      holdLabel: 'Hold to remove',
      doneLabel: 'Removed',
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .unassignWaterChallenge(widget.clientId, c.id);
      if (!mounted) return;
      _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final s = d?.subscription;
    final letter = (s?.displayName.isNotEmpty == true)
        ? s!.displayName[0].toUpperCase()
        : 'C';
    final photoHero = 'client_photo_${widget.clientId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(s?.displayName ?? 'Client'),
        actions: [
          IconButton(
            onPressed: AppHaptics.wrap(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null || s == null
            ? const SizedBox.shrink()
            : ListView(
                padding: PageInsets.page.copyWith(bottom: 40),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProfilePhoto(
                            imageUrl: s.avatarUrl,
                            letter: letter,
                            size: 80,
                            heroTag: photoHero,
                            allowFullscreenWithoutImage: true,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: HpColors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.email,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: HpColors.mutedForeground,
                                  ),
                                ),
                                if (s.mobile != null && s.mobile!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    s.mobile!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: HpColors.mutedForeground,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    StatusPill(
                                      label: planLabel(s.planId),
                                      tone: StatusPillTone.success,
                                    ),
                                    StatusPill(
                                      label: s.status,
                                      tone: s.status == 'active'
                                          ? StatusPillTone.success
                                          : StatusPillTone.neutral,
                                    ),
                                    if (s.daysRemaining != null)
                                      StatusPill(
                                        label: '${s.daysRemaining}d left',
                                        tone: s.expiringSoon
                                            ? StatusPillTone.warning
                                            : StatusPillTone.neutral,
                                      ),
                                    StatusPill(
                                      label: s.appLinked
                                          ? 'App linked'
                                          : 'Not in app',
                                      tone: s.appLinked
                                          ? StatusPillTone.success
                                          : StatusPillTone.neutral,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Expires ${formatDate(s.expiresAt)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: HpColors.mutedForeground,
                                  ),
                                ),
                                if ((s.avatarUrl ?? '').trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Tap photo to view full size',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: HpColors.mutedForeground
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: AppHaptics.wrap(_extend),
                        child: const Text('Extend'),
                      ),
                      OutlinedButton(
                        onPressed: AppHaptics.wrap(_changePlan),
                        child: const Text('Change plan'),
                      ),
                      OutlinedButton(
                        onPressed: AppHaptics.wrap(_cancel),
                        child: const Text('Cancel'),
                      ),
                      if (s.appLinked) ...[
                        OutlinedButton.icon(
                          onPressed: AppHaptics.wrap(() async {
                            final changed = await showAssignWorkoutSheet(
                              context,
                              clientId: widget.clientId,
                            );
                            if (changed == true) _load();
                          }),
                          icon: const Icon(Icons.fitness_center),
                          label: const Text('Assign workout'),
                        ),
                        OutlinedButton.icon(
                          onPressed: AppHaptics.wrap(() async {
                            final changed = await showAssignMealPlanSheet(
                              context,
                              clientId: widget.clientId,
                            );
                            if (changed == true) _load();
                          }),
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('Assign meals'),
                        ),
                        OutlinedButton.icon(
                          onPressed: AppHaptics.wrap(() async {
                            final changed =
                                await showAssignWaterChallengeSheet(
                              context,
                              clientId: widget.clientId,
                            );
                            if (changed == true) _load();
                          }),
                          icon: const Icon(Icons.water_drop_outlined),
                          label: const Text('Assign water'),
                        ),
                      ],
                    ],
                  ),
                  const DetailSectionHeader('Sessions'),
                  ClientSessionsSection(clientId: widget.clientId),
                  const SizedBox(height: 16),
                  const DetailSectionHeader('Progress photos'),
                  _ProgressPhotos(photos: d.progressPhotos),
                  const SizedBox(height: 16),
                  const DetailSectionHeader('Coach desk'),
                  CoachDeskSection(
                    clientId: widget.clientId,
                    notes: d.notes,
                    checkins: d.checkins,
                    onChanged: _load,
                  ),
                  if (d.assignedPlans.isNotEmpty) ...[
                    DetailSectionHeader(
                      'Assigned plans',
                      count: d.assignedPlans.length,
                    ),
                    ...d.assignedPlans.map(
                      (p) => AssignedPlanCard(
                        plan: p,
                        onEdit: s.appLinked
                            ? () async {
                                final changed = await showAssignWorkoutSheet(
                                  context,
                                  clientId: widget.clientId,
                                  existing: p,
                                );
                                if (changed == true) _load();
                              }
                            : null,
                        onDelete: s.appLinked ? () => _unassignPlan(p) : null,
                      ),
                    ),
                  ],
                  if (d.assignedMealPlans.isNotEmpty) ...[
                    DetailSectionHeader(
                      'Assigned meals',
                      count: d.assignedMealPlans.length,
                    ),
                    ...d.assignedMealPlans.map(
                      (p) => AssignedMealPlanCard(
                        plan: p,
                        onEdit: s.appLinked
                            ? () async {
                                final changed = await showAssignMealPlanSheet(
                                  context,
                                  clientId: widget.clientId,
                                  existing: p,
                                );
                                if (changed == true) _load();
                              }
                            : null,
                        onDelete:
                            s.appLinked ? () => _unassignMealPlan(p) : null,
                      ),
                    ),
                  ],
                  if (d.assignedWaterChallenges.isNotEmpty) ...[
                    DetailSectionHeader(
                      'Water challenges',
                      count: d.assignedWaterChallenges.length,
                    ),
                    ...d.assignedWaterChallenges.map(
                      (c) => WaterChallengeCard(
                        challenge: c,
                        onEdit: s.appLinked
                            ? () async {
                                final changed =
                                    await showAssignWaterChallengeSheet(
                                  context,
                                  clientId: widget.clientId,
                                  existing: c,
                                );
                                if (changed == true) _load();
                              }
                            : null,
                        onDelete: s.appLinked
                            ? () => _removeWaterChallenge(c)
                            : null,
                      ),
                    ),
                  ],
                  DetailSectionHeader('Payments', count: d.payments.length),
                  PaymentsCard(payments: d.payments),
                  DetailSectionHeader('Events', count: d.events.length),
                  EventsTimelineCard(events: d.events),
                ],
              ),
      ),
    );
  }
}

class _ProgressPhotos extends StatelessWidget {
  const _ProgressPhotos({required this.photos});

  final List<ClientProgressPhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Text(
        'No progress photos yet.',
        style: GoogleFonts.inter(color: HpColors.mutedForeground),
      );
    }
    final days = <String, Map<String, ClientProgressPhoto>>{};
    for (final photo in photos) {
      days.putIfAbsent(photo.day, () => {})[photo.pose] = photo;
    }
    final ordered = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final day in ordered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final pose in ['front', 'side', 'back']) ...[
                      Expanded(child: _pose(context, days[day]![pose], pose)),
                      if (pose != 'back') const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pose(BuildContext context, ClientProgressPhoto? photo, String pose) {
    final label = switch (pose) {
      'front' => 'Front',
      'side' => 'Side',
      _ => 'Back',
    };
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: HpColors.subtle),
          child: photo == null || photo.url.isEmpty
              ? Center(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: HpColors.mutedForeground,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        child: Image.network(photo.url, fit: BoxFit.contain),
                      ),
                    );
                  },
                  child: Image.network(
                    photo.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: HpColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
