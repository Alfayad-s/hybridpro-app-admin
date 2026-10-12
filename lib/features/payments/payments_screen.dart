import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/list_cards.dart';
import '../../core/utils/haptics.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String? _planId;
  String? _status;
  String _q = '';
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  PaymentsQuery get _query => PaymentsQuery(q: _q, planId: _planId, status: _status);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _q = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(paymentsDashboardProvider(_query));
    final data = async.asData?.value;
    final showBlocking = async.isLoading && data == null;

    return Scaffold(
      appBar: AdminAppBar(
        title: 'Payments',
        searchController: _search,
        searchHint: 'Search email / name',
        onSearchChanged: _onSearchChanged,
        extraActions: [
          if (async.isLoading && data != null)
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
        error: async.hasError && data == null ? async.error.toString() : null,
        onRetry: () => ref.refresh(paymentsDashboardProvider(_query).future),
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(paymentsDashboardProvider(_query).future),
          child: ListView(
            padding: PageInsets.page,
            children: [
              if (data != null) ...[
                StatsRow(
                  children: [
                    MoneyChip(
                      label: 'Collected',
                      value: formatPaise(data.totals.collectedPaise),
                    ),
                    MoneyChip(
                      label: 'Granted',
                      value: formatPaise(data.totals.grantedPaise),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StatsRow(
                  children: [
                    MoneyChip(label: 'Orders', value: '${data.totals.orderCount}'),
                    MoneyChip(label: 'Payers', value: '${data.totals.uniquePayers}'),
                  ],
                ),
                const SizedBox(height: PageInsets.sectionGap),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _planId,
                      decoration: const InputDecoration(labelText: 'Plan'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...planIds.map(
                          (p) => DropdownMenuItem(value: p, child: Text(planLabel(p))),
                        ),
                      ],
                      onChanged: AppHaptics.wrapChanged((v) => setState(() => _planId = v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'granted', child: Text('Granted')),
                      ],
                      onChanged: AppHaptics.wrapChanged((v) => setState(() => _status = v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PageInsets.sectionGap),
              if (data == null)
                const SizedBox.shrink()
              else if (data.payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No payments')),
                )
              else
                ...data.payments.map((p) {
                  return AdminListCard(
                    onTap: p.subscriptionId == null
                        ? null
                        : () => context.push('/clients/${p.subscriptionId}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        children: [
                          MediaThumb(
                            imageUrl: p.avatarUrl,
                            size: 48,
                            icon: Icons.payments_outlined,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CardTitle(
                                  p.fullName?.isNotEmpty == true ? p.fullName! : p.email,
                                ),
                                const SizedBox(height: 4),
                                MetaText(formatDateTime(p.paidAt)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    StatusPill(
                                      label: planLabel(p.planId),
                                      tone: StatusPillTone.success,
                                    ),
                                    StatusPill(
                                      label: p.status,
                                      tone: p.status == 'paid'
                                          ? StatusPillTone.success
                                          : StatusPillTone.neutral,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatPaise(p.amountPaise),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: HpColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
