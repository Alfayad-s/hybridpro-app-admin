import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/exercise_media.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/list_cards.dart';
import '../../../widgets/media_viewer.dart';

class ExerciseTargets {
  const ExerciseTargets({
    required this.sets,
    required this.reps,
    required this.rest,
    this.rpe,
    this.rir,
  });

  final int sets;
  final int reps;
  final int rest;
  /// 6–10. Null means the coach did not set an effort target.
  final int? rpe;
  /// 0–4 reps left. Null means unset.
  final int? rir;
}

String formatRest(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '${m}m' : '$m:${s.toString().padLeft(2, '0')}';
}

/// Full-width editor for an exercise's sets, reps and rest.
Future<ExerciseTargets?> showExerciseTargetsSheet(
  BuildContext context, {
  required String name,
  required ExerciseTargets initial,
  String? imageUrl,
  String? videoUrl,
  String? meta,
}) {
  return showModalBottomSheet<ExerciseTargets>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TargetsSheet(
      name: name,
      initial: initial,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      meta: meta,
    ),
  );
}

class _TargetsSheet extends StatefulWidget {
  const _TargetsSheet({
    required this.name,
    required this.initial,
    this.imageUrl,
    this.videoUrl,
    this.meta,
  });

  final String name;
  final ExerciseTargets initial;
  final String? imageUrl;
  final String? videoUrl;
  final String? meta;

  @override
  State<_TargetsSheet> createState() => _TargetsSheetState();
}

class _TargetsSheetState extends State<_TargetsSheet> {
  late int _sets = widget.initial.sets.clamp(1, 12);
  late int _reps = widget.initial.reps.clamp(1, 50);
  late int _rest = widget.initial.rest.clamp(0, 600);
  late int? _rpe = widget.initial.rpe;
  late int? _rir = widget.initial.rir;

  @override
  Widget build(BuildContext context) {
    final hasVideo = hasExerciseVideo(widget.videoUrl);
    final hasImage = hasExerciseImage(widget.imageUrl);

    return Container(
      decoration: const BoxDecoration(
        color: HpColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                MediaThumb(
                  imageUrl: widget.imageUrl,
                  size: 60,
                  icon: Iconsax.weight,
                  onTap: hasImage
                      ? () => showExerciseImageViewer(
                            context,
                            imageUrl: widget.imageUrl!.trim(),
                            title: widget.name,
                          )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: HpColors.foreground,
                        ),
                      ),
                      if ((widget.meta ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.meta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: HpColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasVideo) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: AppHaptics.wrap(
                      () => showExerciseVideoViewer(
                        context,
                        videoUrl: widget.videoUrl!.trim(),
                        title: widget.name,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HpColors.primary,
                      side: BorderSide(
                        color: HpColors.primary.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 40),
                    ),
                    icon: const Icon(Iconsax.video_play, size: 16),
                    label: const Text('Demo'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            _StepperCard(
              icon: Iconsax.layer,
              label: 'Sets',
              hint: 'Working sets',
              value: '$_sets',
              onMinus: _sets > 1 ? () => setState(() => _sets--) : null,
              onPlus: _sets < 12 ? () => setState(() => _sets++) : null,
              presets: const [2, 3, 4, 5],
              presetLabel: (v) => '$v',
              selectedPreset: _sets,
              onPreset: (v) => setState(() => _sets = v),
            ),
            const SizedBox(height: 12),
            _StepperCard(
              icon: Iconsax.repeat,
              label: 'Reps',
              hint: 'Per set',
              value: '$_reps',
              onMinus: _reps > 1 ? () => setState(() => _reps--) : null,
              onPlus: _reps < 50 ? () => setState(() => _reps++) : null,
              presets: const [6, 8, 10, 12, 15],
              presetLabel: (v) => '$v',
              selectedPreset: _reps,
              onPreset: (v) => setState(() => _reps = v),
            ),
            const SizedBox(height: 12),
            _StepperCard(
              icon: Iconsax.timer_1,
              label: 'Rest',
              hint: 'Between sets',
              value: formatRest(_rest),
              onMinus: _rest > 0
                  ? () => setState(() => _rest = (_rest - 15).clamp(0, 600))
                  : null,
              onPlus: _rest < 600
                  ? () => setState(() => _rest = (_rest + 15).clamp(0, 600))
                  : null,
              presets: const [30, 60, 90, 120, 180],
              presetLabel: formatRest,
              selectedPreset: _rest,
              onPreset: (v) => setState(() => _rest = v),
            ),
            const SizedBox(height: 12),
            _ChoiceRow(
              label: 'RPE',
              hint: 'Effort, 10 is max',
              values: const [6, 7, 8, 9, 10],
              selected: _rpe,
              onChanged: (v) => setState(() => _rpe = v),
            ),
            const SizedBox(height: 12),
            _ChoiceRow(
              label: 'RIR',
              hint: 'Reps left in reserve',
              values: const [0, 1, 2, 3, 4],
              selected: _rir,
              onChanged: (v) => setState(() => _rir = v),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: HpColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                [
                  '$_sets sets × $_reps reps',
                  '${formatRest(_rest)} rest',
                  if (_rpe != null) 'RPE $_rpe',
                  if (_rir != null) 'RIR $_rir',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HpColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        AppHaptics.wrap(() => Navigator.pop(context)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: AppHaptics.wrap(
                      () => Navigator.pop(
                        context,
                        ExerciseTargets(
                          sets: _sets,
                          reps: _reps,
                          rest: _rest,
                          rpe: _rpe,
                          rir: _rir,
                        ),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Save targets'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.hint,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final List<int> values;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: HpColors.subtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HpColors.foreground,
            ),
          ),
          Text(
            hint,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: HpColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PresetChip(
                  label: 'Off',
                  selected: selected == null,
                  onTap: () => onChanged(null),
                ),
              ),
              for (final value in values) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _PresetChip(
                    label: '$value',
                    selected: selected == value,
                    onTap: () => onChanged(value),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.presets,
    required this.presetLabel,
    required this.selectedPreset,
    required this.onPreset,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final List<int> presets;
  final String Function(int) presetLabel;
  final int selectedPreset;
  final ValueChanged<int> onPreset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: HpColors.subtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: HpColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: HpColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HpColors.foreground,
                      ),
                    ),
                    Text(
                      hint,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: HpColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              _StepButton(icon: Icons.remove_rounded, onTap: onMinus),
              SizedBox(
                width: 72,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: HpColors.foreground,
                  ),
                ),
              ),
              _StepButton(icon: Icons.add_rounded, onTap: onPlus, filled: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _PresetChip(
                    label: presetLabel(presets[i]),
                    selected: presets[i] == selectedPreset,
                    onTap: () => onPreset(presets[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = filled
        ? (enabled ? HpColors.primary : HpColors.primary.withValues(alpha: 0.25))
        : HpColors.card;
    final fg = filled
        ? HpColors.primaryForeground
        : (enabled ? HpColors.foreground : HpColors.mutedForeground);
    return Material(
      color: bg,
      shape: CircleBorder(
        side: filled ? BorderSide.none : const BorderSide(color: HpColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? AppHaptics.wrap(onTap) : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
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
        duration: const Duration(milliseconds: 160),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? HpColors.primary.withValues(alpha: 0.16)
              : HpColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? HpColors.primary.withValues(alpha: 0.6)
                : HpColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? HpColors.primary : HpColors.foreground,
          ),
        ),
      ),
    );
  }
}
