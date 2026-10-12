import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/api/admin_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/chat_models.dart';
import '../../../core/chat/chat_inbox_controller.dart';
import '../../../core/realtime/admin_session_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/prompt_chat_input.dart';

class ClientChatSection extends ConsumerStatefulWidget {
  const ClientChatSection({
    super.key,
    required this.clientId,
    this.expanded = false,
  });

  final String clientId;

  /// Full-page layout (no card chrome, fills available height).
  final bool expanded;

  @override
  ConsumerState<ClientChatSection> createState() => _ClientChatSectionState();
}

class _ClientChatSectionState extends ConsumerState<ClientChatSection> {
  final _scroll = ScrollController();
  final _compose = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<ChatMessage> _messages = const [];
  ProviderContainer? _container;
  String _memberUserId = '';
  String? _memberLastReadAt;
  bool _memberTyping = false;
  Timer? _typingClear;
  Timer? _typingDebounce;
  var _sentTyping = false;

  @override
  void initState() {
    super.initState();
    _compose.addListener(_onComposeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adminSessionServicesProvider).start();
      ref
          .read(activeAdminChatSubscriptionProvider.notifier)
          .set(widget.clientId);
      _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context);
  }

  @override
  void dispose() {
    _typingClear?.cancel();
    _typingDebounce?.cancel();
    _compose.removeListener(_onComposeChanged);
    final container = _container;
    final clientId = widget.clientId;
    final memberUserId = _memberUserId;
    Future<void>(() {
      if (container == null) return;
      final active = container.read(activeAdminChatSubscriptionProvider);
      if (active == clientId) {
        container
            .read(activeAdminChatSubscriptionProvider.notifier)
            .set(null);
      }
      if (memberUserId.isNotEmpty) {
        container.read(adminSessionServicesProvider).emitTyping(
              subscriptionId: clientId,
              memberUserId: memberUserId,
              isTyping: false,
            );
      }
    });
    _compose.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onComposeChanged() {
    final typing = _compose.text.trim().isNotEmpty;
    if (_memberUserId.isEmpty) return;
    if (typing && !_sentTyping) {
      _sentTyping = true;
      ref.read(adminSessionServicesProvider).emitTyping(
            subscriptionId: widget.clientId,
            memberUserId: _memberUserId,
            isTyping: true,
          );
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (!_sentTyping) return;
      _sentTyping = false;
      ref.read(adminSessionServicesProvider).emitTyping(
            subscriptionId: widget.clientId,
            memberUserId: _memberUserId,
            isTyping: false,
          );
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final thread =
          await ref.read(adminRepositoryProvider).clientChat(widget.clientId);
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _memberUserId = thread.conversation.memberUserId;
        _memberLastReadAt = thread.conversation.memberLastReadAt;
        _loading = false;
      });
      await ref.read(adminRepositoryProvider).markClientChatRead(widget.clientId);
      ref.read(chatInboxProvider.notifier).clearUnread(widget.clientId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isSeenByMember(ChatMessage message) {
    if (!message.isCoach) return false;
    final readAt = _memberLastReadAt;
    if (readAt == null || readAt.isEmpty) return false;
    final read = DateTime.tryParse(readAt);
    final created = DateTime.tryParse(message.createdAt);
    if (read == null || created == null) return false;
    return !read.isBefore(created);
  }

  Future<bool> _send(
    String text,
    List<PromptChatAttachment> files,
  ) async {
    if (_sending) return false;
    if (text.isEmpty && files.isEmpty) return false;
    setState(() => _sending = true);
    _sentTyping = false;
    if (_memberUserId.isNotEmpty) {
      ref.read(adminSessionServicesProvider).emitTyping(
            subscriptionId: widget.clientId,
            memberUserId: _memberUserId,
            isTyping: false,
          );
    }
    final repo = ref.read(adminRepositoryProvider);
    try {
      ChatMessage? last;
      if (files.isNotEmpty) {
        for (var i = 0; i < files.length; i++) {
          final file = files[i];
          final url = await repo.uploadExerciseMedia(
            filePath: file.path,
            filename: file.name,
            kind: 'image',
            exerciseKey: 'chat-${DateTime.now().millisecondsSinceEpoch}-$i',
          );
          last = await repo.sendClientChat(
            widget.clientId,
            body: i == 0 ? text : '',
            imageUrl: url,
          );
          if (!mounted) return false;
          setState(() {
            _messages = [..._messages.where((m) => m.id != last!.id), last!];
          });
        }
      } else {
        last = await repo.sendClientChat(
          widget.clientId,
          body: text,
        );
        if (!mounted) return false;
        setState(() {
          _messages = [..._messages.where((m) => m.id != last!.id), last!];
        });
      }
      if (!mounted) return false;
      setState(() => _sending = false);
      _scrollToEnd();
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return false;
    }
  }

  void ingestRealtime(Map<String, String> data) {
    final type = data['type'] ?? '';
    final subId = data['subscriptionId'] ?? '';
    // Prefer subscription-scoped events; allow empty subId (legacy typing).
    if (subId.isNotEmpty && subId != widget.clientId) return;

    if (type == 'chat.typing') {
      if ((data['senderRole'] ?? '') != 'member') return;
      final typing = data['isTyping'] == '1' || data['isTyping'] == 'true';
      _typingClear?.cancel();
      if (!mounted) return;
      setState(() => _memberTyping = typing);
      if (typing) {
        _typingClear = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _memberTyping = false);
        });
      }
      return;
    }

    if (type == 'chat.read') {
      if ((data['readerRole'] ?? '') == 'member') {
        setState(() {
          _memberLastReadAt = data['readAt'] ?? _memberLastReadAt;
        });
      }
      return;
    }

    if (type != 'chat.message') return;
    final message = ChatMessage.fromJson(data);
    if (message.id.isEmpty || _messages.any((m) => m.id == message.id)) return;
    setState(() {
      _messages = [..._messages, message];
      _memberTyping = false;
    });
    if (message.isMember) {
      ref.read(adminRepositoryProvider).markClientChatRead(widget.clientId);
      ref.read(chatInboxProvider.notifier).clearUnread(widget.clientId);
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, String>?>(adminChatRealtimeProvider, (prev, next) {
      if (next == null) return;
      ingestRealtime(next);
    });

    final messagesBody = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: HpColors.mutedForeground,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            : _messages.isEmpty && !_memberTyping
                ? Center(
                    child: Text(
                      'No messages yet — say hello',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: HpColors.mutedForeground,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: _messages.length + (_memberTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_memberTyping && index == _messages.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                              'typing…',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: HpColors.primary,
                              ),
                            ),
                          ),
                        );
                      }
                      final message = _messages[index];
                      final mine = message.isCoach;
                      final time = DateTime.tryParse(message.createdAt);
                      final seen = mine && _isSeenByMember(message);
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? HpColors.primary.withValues(alpha: 0.18)
                                : HpColors.subtle,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(mine ? 14 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.body.trim().isEmpty
                                    ? (message.imageUrl != null ? 'Photo' : '')
                                    : message.body,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: HpColors.foreground,
                                  height: 1.35,
                                ),
                              ),
                              if (message.imageUrl != null) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    message.imageUrl!,
                                    height: 140,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                              if (time != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat.jm().format(time.toLocal()),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: HpColors.mutedForeground,
                                      ),
                                    ),
                                    if (mine) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        seen
                                            ? Icons.done_all_rounded
                                            : Icons.done_rounded,
                                        size: 14,
                                        color: seen
                                            ? HpColors.primary
                                            : HpColors.mutedForeground,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );

    final composer = SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          widget.expanded ? 10 : 12,
        ),
        child: PromptChatInput(
          controller: _compose,
          isLoading: _sending,
          enabled: !_loading && _error == null,
          onSubmit: _send,
        ),
      ),
    );

    if (widget.expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_memberTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Member is typing…',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: HpColors.primary,
                ),
              ),
            ),
          Expanded(child: messagesBody),
          composer,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: HpColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'Chat',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
                if (_memberTyping) ...[
                  const SizedBox(width: 8),
                  Text(
                    'typing…',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HpColors.primary,
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  onPressed: AppHaptics.wrap(_load),
                  icon: const Icon(Iconsax.refresh, size: 18),
                ),
              ],
            ),
          ),
          SizedBox(height: 280, child: messagesBody),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: PromptChatInput(
              controller: _compose,
              isLoading: _sending,
              enabled: !_loading && _error == null,
              onSubmit: _send,
            ),
          ),
        ],
      ),
    );
  }
}
