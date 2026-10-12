import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/list_cards.dart';
import '../../core/utils/haptics.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String? _status;
  String _q = '';
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  ContactsQuery get _query => ContactsQuery(q: _q, status: _status);

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

  StatusPillTone _toneFor(String status) {
    return switch (status) {
      'new' => StatusPillTone.warning,
      'converted' => StatusPillTone.success,
      _ => StatusPillTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(contactsProvider(_query));
    final items = async.asData?.value ?? const <ContactSubmission>[];
    final showBlocking = async.isLoading && async.asData?.value == null;

    return Scaffold(
      appBar: AdminAppBar(
        title: 'Contacts',
        searchController: _search,
        searchHint: 'Search contacts',
        onSearchChanged: _onSearchChanged,
        extraActions: [
          if (async.isLoading && async.asData?.value != null)
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilterBar(
              children: [
                for (final entry in {
                  null: 'All',
                  'new': 'New',
                  'read': 'Read',
                  'converted': 'Converted',
                }.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _status == entry.key,
                    onSelected: AppHaptics.wrapChanged(
                      (_) => setState(() => _status = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody(
              loading: showBlocking,
              error: async.hasError && async.asData?.value == null
                  ? async.error.toString()
                  : null,
              onRetry: () => ref.refresh(contactsProvider(_query).future),
              empty: !showBlocking && items.isEmpty,
              emptyLabel: 'No contacts',
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(contactsProvider(_query).future),
                child: ListView.builder(
                  padding: PageInsets.page.copyWith(top: 0),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return AdminListCard(
                      onTap: () async {
                        await context.push('/contacts/${c.id}');
                        ref.invalidate(contactsProvider(_query));
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: HpColors.subtle,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Iconsax.sms,
                                color: HpColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CardTitle(c.name),
                                  const SizedBox(height: 4),
                                  MetaText(c.email),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      StatusPill(
                                        label: c.status,
                                        tone: _toneFor(c.status),
                                      ),
                                      StatusPill(
                                        label: formatDateTime(c.createdAt),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: HpColors.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
