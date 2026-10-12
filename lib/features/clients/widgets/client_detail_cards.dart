import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../widgets/list_cards.dart';
import 'assigned_plan_card.dart';

String _capitalize(String s) {
  final t = s.replaceAll('_', ' ').trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}

BoxDecoration _cardDecoration({bool glow = false}) => BoxDecoration(
      color: HpColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HpColors.border),
      gradient: glow
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HpColors.primary.withValues(alpha: 0.07),
                HpColors.card,
                HpColors.card,
              ],
              stops: const [0, 0.35, 1],
            )
          : null,
    );

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    this.color = HpColors.primary,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDelete == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        if (onEdit != null)
          CardRoundAction(icon: Iconsax.edit_2, tooltip: 'Edit', onTap: onEdit!),
        if (onDelete != null) ...[
          const SizedBox(width: 6),
          CardRoundAction(
            icon: Iconsax.trash,
            tooltip: 'Remove',
            color: HpColors.destructive,
            onTap: onDelete!,
          ),
        ],
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: HpColors.mutedForeground,
      ),
    );
  }
}

/// Section heading with an optional count badge.
class DetailSectionHeader extends StatelessWidget {
  const DetailSectionHeader(this.title, {super.key, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: HpColors.foreground,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: HpColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: HpColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Water challenge ──────────────────────────────────────────

class WaterChallengeCard extends StatelessWidget {
  const WaterChallengeCard({
    super.key,
    required this.challenge,
    this.onEdit,
    this.onDelete,
  });

  final AssignedWaterChallenge challenge;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const _water = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(challenge.startDate);
    final end = DateTime.tryParse(challenge.endDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final total = challenge.durationDays <= 0 ? 1 : challenge.durationDays;

    String status;
    StatusPillTone tone;
    int elapsed;
    if (start == null || end == null) {
      status = challenge.isActive ? 'Active' : 'Inactive';
      tone = challenge.isActive ? StatusPillTone.success : StatusPillTone.neutral;
      elapsed = 0;
    } else if (today.isBefore(start)) {
      status = 'Starts ${formatDate(challenge.startDate)}';
      tone = StatusPillTone.warning;
      elapsed = 0;
    } else if (today.isAfter(end)) {
      status = 'Ended';
      tone = StatusPillTone.neutral;
      elapsed = total;
    } else {
      elapsed = (today.difference(start).inDays + 1).clamp(0, total);
      status = 'Day $elapsed of $total';
      tone = StatusPillTone.success;
    }
    final liters = (challenge.targetMlPerDay / 1000).toStringAsFixed(
      challenge.targetMlPerDay % 1000 == 0 ? 0 : 1,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBadge(icon: Iconsax.drop, color: _water),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title.isEmpty ? 'Water challenge' : challenge.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: HpColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusPill(label: status, tone: tone),
                  ],
                ),
              ),
              _Actions(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${liters}L',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: HpColors.foreground,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _Meta('per day · ${challenge.targetMlPerDay} ml'),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _Meta('${challenge.durationDays} days'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: elapsed / total,
              minHeight: 6,
              backgroundColor: HpColors.subtle,
              valueColor: const AlwaysStoppedAnimation(_water),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Iconsax.calendar_1,
                size: 14,
                color: HpColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              _Meta(
                '${formatDate(challenge.startDate)}  →  ${formatDate(challenge.endDate)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Payments ─────────────────────────────────────────────────

class PaymentsCard extends StatelessWidget {
  const PaymentsCard({super.key, required this.payments});

  final List<AdminPayment> payments;

  StatusPillTone _tone(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'captured':
      case 'success':
        return StatusPillTone.success;
      case 'failed':
      case 'refunded':
        return StatusPillTone.danger;
      case 'pending':
      case 'created':
        return StatusPillTone.warning;
      default:
        return StatusPillTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const _EmptyCard(icon: Iconsax.receipt_2, label: 'No payments yet');
    }
    final paid = payments
        .where((p) => _tone(p.status) == StatusPillTone.success)
        .fold<int>(0, (s, p) => s + p.amountPaise);

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                _Meta('Total collected'),
                const Spacer(),
                Text(
                  formatPaise(paid),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: HpColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: HpColors.border),
          for (var i = 0; i < payments.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 70,
                color: HpColors.border,
              ),
            _PaymentRow(payment: payments[i], tone: _tone(payments[i].status)),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.tone});

  final AdminPayment payment;
  final StatusPillTone tone;

  @override
  Widget build(BuildContext context) {
    final plan = payment.planName.isNotEmpty
        ? payment.planName
        : planLabel(payment.planId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const _IconBadge(icon: Iconsax.receipt_2, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPaise(payment.amountPaise),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$plan · ${formatDateTime(payment.paidAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: HpColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(label: _capitalize(payment.status), tone: tone),
        ],
      ),
    );
  }
}

// ─── Events ───────────────────────────────────────────────────

class EventsTimelineCard extends StatelessWidget {
  const EventsTimelineCard({super.key, required this.events});

  final List<SubscriptionEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyCard(icon: Iconsax.activity, label: 'No events yet');
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            _TimelineRow(event: events[i], isLast: i == events.length - 1),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final SubscriptionEvent event;
  final bool isLast;

  (IconData, Color) _style() {
    switch (event.action.toLowerCase()) {
      case 'activated':
      case 'created':
        return (Iconsax.tick_circle, HpColors.primary);
      case 'renewed':
        return (Iconsax.refresh, HpColors.primary);
      case 'extended':
      case 'extend':
        return (Iconsax.calendar_add, const Color(0xFF38BDF8));
      case 'change_plan':
      case 'plan_changed':
      case 'changed':
        return (Iconsax.arrow_swap_horizontal, const Color(0xFFF59E0B));
      case 'cancelled':
      case 'cancel':
      case 'expired':
        return (Iconsax.close_circle, HpColors.destructive);
      default:
        return (Iconsax.activity, HpColors.mutedForeground);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style();
    final plan = event.planName.isNotEmpty
        ? event.planName
        : planLabel(event.planId);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: HpColors.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: isLast ? 12 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _capitalize(event.action),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HpColors.foreground,
                          ),
                        ),
                      ),
                      if (event.amountPaise != null && event.amountPaise! > 0)
                        Text(
                          formatPaise(event.amountPaise!),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HpColors.foreground,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HpColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _Meta(formatDateTime(event.createdAt)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: _cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: HpColors.mutedForeground),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: HpColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
