import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/chat_models.dart';
import '../../core/api/models.dart';
import '../../core/chat/chat_inbox_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/profile_photo.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _query = '';
  var _loadingInbox = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(chatInboxProvider.notifier).refresh();
      if (mounted) setState(() => _loadingInbox = false);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  void _openChat({
    required String clientId,
    required String title,
    String? subtitle,
    String? avatarUrl,
  }) {
    context.push(
      '/messages/$clientId',
      extra: ClientChatArgs(
        title: title,
        subtitle: subtitle,
        avatarUrl: avatarUrl,
      ),
    );
  }

  Future<void> _openNewChatPicker() async {
    final selected = await showModalBottomSheet<AdminClient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _NewChatPickerSheet(),
    );
    if (selected == null || !mounted) return;
    _openChat(
      clientId: selected.id,
      title: selected.displayName,
      subtitle: selected.email,
      avatarUrl: selected.avatarUrl,
    );
  }

  String _timeLabel(ChatInboxItem item) {
    final raw = item.lastMessage?.createdAt ??
        item.conversation.lastMessageAt ??
        item.conversation.createdAt;
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return DateFormat.jm().format(dt);
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(dt).inDays < 7) return DateFormat.E().format(dt);
    return DateFormat.MMMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(chatInboxProvider);
    final filtered = _query.isEmpty
        ? inbox
        : inbox
            .where((item) {
              final hay =
                  '${item.displayName} ${item.email}'.toLowerCase();
              return hay.contains(_query);
            })
            .toList();

    final unreadTotal = inbox.fold<int>(
      0,
      (sum, item) => sum + item.conversation.unreadCount,
    );

    return Scaffold(
      backgroundColor: HpColors.background,
      appBar: AppBar(
        backgroundColor: HpColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: AppHaptics.wrap(() => context.pop()),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: HpColors.foreground,
                letterSpacing: -0.4,
              ),
            ),
            if (unreadTotal > 0)
              Text(
                '$unreadTotal unread',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HpColors.primary,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'messages_new_chat_fab',
        backgroundColor: HpColors.primary,
        foregroundColor: HpColors.primaryForeground,
        onPressed: AppHaptics.wrap(_openNewChatPicker),
        child: const Icon(Iconsax.message_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search chats',
                prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
                filled: true,
                fillColor: const Color(0xFF1A1A1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: HpColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (_query.isEmpty || 'hyrox group'.contains(_query))
            ListTile(
              leading: const CircleAvatar(child: Text('H')),
              title: Text(
                'Hyrox group',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Open room for every Hyrox member'),
              onTap: () => context.push('/messages/hyrox'),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _loadingInbox = true);
                await ref.read(chatInboxProvider.notifier).refresh();
                if (mounted) setState(() => _loadingInbox = false);
              },
              child: _loadingInbox && inbox.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                          children: [
                            Icon(
                              Iconsax.message,
                              size: 48,
                              color: HpColors.mutedForeground
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _query.isEmpty
                                  ? 'No conversations yet'
                                  : 'No chats match',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: HpColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _query.isEmpty
                                  ? 'Tap + to message a client'
                                  : 'Try a different name or email',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: HpColors.mutedForeground,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            indent: 76,
                            color: HpColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final unread = item.conversation.unreadCount;
                            final preview = item.lastMessage?.body.trim();
                            final letter = item.displayName.isNotEmpty
                                ? item.displayName[0].toUpperCase()
                                : '?';

                            return InkWell(
                              onTap: AppHaptics.wrap(
                                () => _openChat(
                                  clientId: item.subscriptionId,
                                  title: item.displayName,
                                  subtitle: item.email,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    ProfilePhoto(
                                      imageUrl: null,
                                      letter: letter,
                                      size: 52,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: unread > 0
                                                        ? FontWeight.w800
                                                        : FontWeight.w700,
                                                    color: HpColors.foreground,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _timeLabel(item),
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: unread > 0
                                                      ? HpColors.primary
                                                      : HpColors
                                                          .mutedForeground,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  (preview == null ||
                                                          preview.isEmpty)
                                                      ? 'No messages'
                                                      : preview,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: unread > 0
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    color: unread > 0
                                                        ? HpColors.foreground
                                                            .withValues(
                                                              alpha: 0.85,
                                                            )
                                                        : HpColors
                                                            .mutedForeground,
                                                  ),
                                                ),
                                              ),
                                              if (unread > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 22,
                                                  ),
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: HpColors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      99,
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    unread > 99
                                                        ? '99+'
                                                        : '$unread',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: HpColors
                                                          .primaryForeground,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Args passed via go_router `extra` into [ClientChatScreen].
class ClientChatArgs {
  const ClientChatArgs({
    this.title,
    this.subtitle,
    this.avatarUrl,
  });

  final String? title;
  final String? subtitle;
  final String? avatarUrl;
}

class _NewChatPickerSheet extends ConsumerStatefulWidget {
  const _NewChatPickerSheet();

  @override
  ConsumerState<_NewChatPickerSheet> createState() =>
      _NewChatPickerSheetState();
}

class _NewChatPickerSheetState extends ConsumerState<_NewChatPickerSheet> {
  final _search = TextEditingController();
  var _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      clientsListProvider(ClientsQuery(q: _q)),
    );
    final clients = async.asData?.value ?? const <AdminClient>[];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HpColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'New message',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: HpColors.foreground,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v.trim()),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search clients',
                prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
                filled: true,
                fillColor: HpColors.subtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: async.isLoading && clients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : clients.isEmpty
                    ? Center(
                        child: Text(
                          'No clients found',
                          style: GoogleFonts.inter(
                            color: HpColors.mutedForeground,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: bottom + 16),
                        itemCount: clients.length,
                        itemBuilder: (context, index) {
                          final c = clients[index];
                          final letter = c.displayName.isNotEmpty
                              ? c.displayName[0].toUpperCase()
                              : '?';
                          return ListTile(
                            onTap: AppHaptics.wrap(
                              () => Navigator.pop(context, c),
                            ),
                            leading: ProfilePhoto(
                              imageUrl: c.avatarUrl,
                              letter: letter,
                              size: 44,
                            ),
                            title: Text(
                              c.displayName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: HpColors.foreground,
                              ),
                            ),
                            subtitle: Text(
                              c.email,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: HpColors.mutedForeground,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
