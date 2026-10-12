import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_providers.dart';
import '../../core/chat/chat_inbox_controller.dart';
import '../../core/realtime/admin_session_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/haptics.dart';
import '../../features/messages/messages_screen.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/stat_chart_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(adminStatsProvider);
    final stats = async.asData?.value;
    final showBlocking = async.isLoading && stats == null;

    return Scaffold(
      backgroundColor: HpColors.background,
      appBar: AdminAppBar(
        title: 'Dashboard',
        enableSearch: false,
        extraActions: [
          if (async.isLoading && stats != null)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: AsyncBody(
        loading: showBlocking,
        error: async.hasError && stats == null ? async.error.toString() : null,
        onRetry: () => ref.refresh(adminStatsProvider.future),
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(adminStatsProvider.future),
              ref.read(activeGymSessionsProvider.notifier).refresh(),
              ref.read(chatInboxProvider.notifier).refresh(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              if (stats != null) ...[
                StatChartCard(
                  label: 'Revenue · last 14 days',
                  value: formatPaise(stats.revenuePaise),
                  subtitle:
                      '${stats.paidOrders} paid orders · ${stats.paidClients} payers',
                  accent: ChartPalette.revenue,
                  series: asChartSeries(stats.trends.revenuePaise),
                  featured: true,
                  onTap: AppHaptics.wrap(() => context.go('/payments')),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatChartCard(
                        label: 'Orders / day',
                        value: '${stats.paidOrders}',
                        subtitle: 'Last 14 days',
                        accent: ChartPalette.orders,
                        series: asChartSeries(stats.trends.paidOrders),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatChartCard(
                        label: 'New clients',
                        value: '${_sum(stats.trends.signups)}',
                        subtitle: 'Last 14 days',
                        accent: ChartPalette.signups,
                        series: asChartSeries(stats.trends.signups),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionLabel('Clients'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatChartCard(
                        label: 'Active',
                        value: '${stats.active}',
                        accent: ChartPalette.active,
                        proportion: _share(stats.active, stats.total),
                        onTap: AppHaptics.wrap(() => context.go('/clients')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatChartCard(
                        label: 'Expired',
                        value: '${stats.expired}',
                        accent: ChartPalette.expired,
                        proportion: _share(stats.expired, stats.total),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatChartCard(
                        label: 'Expiring soon',
                        value: '${stats.expiringSoon}',
                        accent: ChartPalette.soon,
                        proportion: _share(stats.expiringSoon, stats.total),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatChartCard(
                        label: 'Total clients',
                        value: '${stats.total}',
                        accent: ChartPalette.total,
                        proportion: stats.total == 0 ? 0 : 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MixBarChart(
                  title: 'Status mix',
                  segments: [
                    (
                      label: 'Active',
                      value: stats.active,
                      color: ChartPalette.active,
                    ),
                    (
                      label: 'Soon',
                      value: stats.expiringSoon,
                      color: ChartPalette.soon,
                    ),
                    (
                      label: 'Expired',
                      value: stats.expired,
                      color: ChartPalette.expired,
                    ),
                  ],
                ),
                if (stats.byPlan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PlanBarsCard(byPlan: stats.byPlan),
                ],
                const SizedBox(height: 28),
              ],
              const _ChatInboxSection(),
              const SizedBox(height: 28),
              const _InGymNowSection(),
              const SizedBox(height: 28),
              const _SectionLabel('Quick links'),
              const SizedBox(height: 12),
              _QuickLink(
                icon: Iconsax.people,
                title: 'Clients',
                subtitle: 'Manage subscriptions',
                onTap: () => context.go('/clients'),
              ),
              _QuickLink(
                icon: Iconsax.wallet_money,
                title: 'Payments',
                subtitle: 'Orders and revenue',
                onTap: () => context.go('/payments'),
              ),
              _QuickLink(
                icon: Iconsax.sms,
                title: 'Contacts',
                subtitle: 'Lead submissions',
                onTap: () => context.go('/contacts'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _share(int part, int total) {
    if (total <= 0) return 0;
    return part / total;
  }

  int _sum(List<int> values) => values.fold(0, (a, b) => a + b);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: HpColors.foreground,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChartPalette.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: AppHaptics.wrap(onTap),
              borderRadius: BorderRadius.circular(24),
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

class _PlanBarsCard extends StatelessWidget {
  const _PlanBarsCard({required this.byPlan});

  final Map<String, int> byPlan;

  @override
  Widget build(BuildContext context) {
    final entries = byPlan.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final safeMax = max <= 0 ? 1 : max;
    const colors = [
      ChartPalette.active,
      ChartPalette.soon,
      ChartPalette.signups,
      ChartPalette.expired,
    ];

    return _DashCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By plan',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HpColors.foreground,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    planLabel(entries[i].key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HpColors.foreground,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: entries[i].value / safeMax,
                      minHeight: 8,
                      backgroundColor: ChartPalette.track,
                      color: colors[i % colors.length].withValues(alpha: 0.75),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${entries[i].value}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HpColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _DashCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: HpColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: HpColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: HpColors.foreground,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HpColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: HpColors.mutedForeground.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInboxSection extends ConsumerWidget {
  const _ChatInboxSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(chatInboxProvider);
    final unreadTotal =
        items.fold<int>(0, (sum, item) => sum + item.conversation.unreadCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Chat inbox')),
            Text(
              unreadTotal > 0 ? '$unreadTotal unread' : '${items.length}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: HpColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _DashCard(
            child: Text(
              'No conversations yet',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HpColors.mutedForeground,
              ),
            ),
          )
        else
          ...items.take(8).map((item) {
            final preview = item.lastMessage?.body.trim() ?? 'No messages';
            final unread = item.conversation.unreadCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DashCard(
                onTap: () => context.push(
                  '/messages/${item.subscriptionId}',
                  extra: ClientChatArgs(
                    title: item.displayName,
                    subtitle: item.email,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: HpColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Iconsax.message,
                        size: 18,
                        color: HpColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: HpColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HpColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$unread',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: HpColors.mutedForeground.withValues(alpha: 0.7),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _InGymNowSection extends ConsumerWidget {
  const _InGymNowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(activeGymSessionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('In gym now')),
            Text(
              '${sessions.length}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: HpColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          _DashCard(
            child: Text(
              'No members checked in',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HpColors.mutedForeground,
              ),
            ),
          )
        else
          ...sessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DashCard(
                onTap: () =>
                    context.push('/clients/${session.subscriptionId}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Iconsax.location,
                        size: 18,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: HpColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            session.email,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HpColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: HpColors.mutedForeground.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
