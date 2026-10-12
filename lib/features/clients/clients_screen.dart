import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/utils/format.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/list_cards.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/rubber_segment.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String? _status;
  String? _planId;
  bool _expiringSoon = false;
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  ClientsQuery get _query => ClientsQuery(
        q: _search.text.trim(),
        status: _status,
        planId: _planId,
        expiringSoon: _expiringSoon,
      );

  String get _filterValue {
    if (_expiringSoon) return 'expiring';
    if (_status == 'active') return 'active';
    if (_status == 'expired') return 'expired';
    return 'all';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _showGrant() async {
    final email = TextEditingController();
    final mobile = TextEditingController();
    var planId = 'performance';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Grant plan', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mobile,
                    decoration: const InputDecoration(labelText: 'Mobile (optional)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: planId,
                    items: planIds
                        .map((p) => DropdownMenuItem(value: p, child: Text(planLabel(p))))
                        .toList(),
                    onChanged: AppHaptics.wrapChanged((v) => setModal(() => planId = v ?? planId)),
                    decoration: const InputDecoration(labelText: 'Plan'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, true)),
                    child: const Text('Grant access'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(adminRepositoryProvider).grantClient(
            email: email.text,
            mobile: mobile.text,
            planId: planId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan granted')),
      );
      ref.invalidate(adminStatsProvider);
      await ref.refresh(clientsListProvider(_query).future);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      email.dispose();
      mobile.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(clientsListProvider(_query));
    final clients = async.asData?.value;
    final showBlocking = async.isLoading && clients == null;

    return Scaffold(
      appBar: AdminAppBar(
        title: 'Clients',
        searchController: _search,
        searchHint: 'Search email, name, mobile',
        onSearchChanged: _onSearchChanged,
        extraActions: [
          if (async.isLoading && clients != null)
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'clients_grant_fab',
        onPressed: AppHaptics.wrap(_showGrant),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Grant'),
      ),
      body: AsyncBody(
        loading: showBlocking,
        error: async.hasError && clients == null ? async.error.toString() : null,
        onRetry: () => ref.refresh(clientsListProvider(_query).future),
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(clientsListProvider(_query).future),
          child: ListView(
            padding: PageInsets.page,
            children: [
              RubberSegment(
                value: _filterValue,
                items: const [
                  RubberSegmentItem(value: 'all', label: 'All'),
                  RubberSegmentItem(value: 'active', label: 'Active'),
                  RubberSegmentItem(value: 'expired', label: 'Expired'),
                  RubberSegmentItem(value: 'expiring', label: 'Expiring'),
                ],
                onChanged: (v) {
                  setState(() {
                    switch (v) {
                      case 'active':
                        _status = 'active';
                        _expiringSoon = false;
                      case 'expired':
                        _status = 'expired';
                        _expiringSoon = false;
                      case 'expiring':
                        _status = null;
                        _expiringSoon = true;
                      default:
                        _status = null;
                        _expiringSoon = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _planId,
                decoration: const InputDecoration(labelText: 'Plan filter'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All plans')),
                  ...planIds.map(
                    (p) => DropdownMenuItem(value: p, child: Text(planLabel(p))),
                  ),
                ],
                onChanged: AppHaptics.wrapChanged((v) => setState(() => _planId = v)),
              ),
              const SizedBox(height: PageInsets.sectionGap),
              if (clients == null)
                const SizedBox.shrink()
              else if (clients.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No clients match')),
                )
              else
                ...clients.map((c) {
                  final tone = c.status == 'active'
                      ? StatusPillTone.success
                      : c.expiringSoon
                          ? StatusPillTone.warning
                          : StatusPillTone.neutral;
                  return AdminListCard(
                    onTap: () => context.push('/clients/${c.id}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                      child: Row(
                        children: [
                          MediaThumb(
                            imageUrl: c.avatarUrl,
                            size: 52,
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CardTitle(c.displayName),
                                const SizedBox(height: 4),
                                MetaText(c.email),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    StatusPill(
                                      label: planLabel(c.planId),
                                      tone: StatusPillTone.success,
                                    ),
                                    StatusPill(label: c.status, tone: tone),
                                    if (c.daysRemaining != null)
                                      StatusPill(
                                        label: '${c.daysRemaining}d left',
                                        tone: c.expiringSoon
                                            ? StatusPillTone.warning
                                            : StatusPillTone.neutral,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF9CA3AF),
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
