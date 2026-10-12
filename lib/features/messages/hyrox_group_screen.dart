import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/admin_repository.dart';
import '../../core/api/chat_models.dart';
import '../../core/chat/chat_inbox_controller.dart';
import '../../core/theme/app_theme.dart';

/// Coach side of the one shared Hyrox room.
class HyroxGroupScreen extends ConsumerStatefulWidget {
  const HyroxGroupScreen({super.key});

  @override
  ConsumerState<HyroxGroupScreen> createState() => _HyroxGroupScreenState();
}

class _HyroxGroupScreenState extends ConsumerState<HyroxGroupScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final thread = await ref.read(adminRepositoryProvider).hyroxChat();
      await ref.read(adminRepositoryProvider).markHyroxRead();
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message =
          await ref.read(adminRepositoryProvider).sendHyroxChat(body: text);
      _input.clear();
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (!_messages.any((m) => m.id == message.id)) {
          _messages = [..._messages, message];
        }
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminChatRealtimeProvider, (prev, next) {
      if (next == null || next['type'] != 'hyrox.chat') return;
      final message = ChatMessage.fromJson(next);
      if (message.id.isEmpty || _messages.any((m) => m.id == message.id)) return;
      setState(() => _messages = [..._messages, message]);
      _scrollToEnd();
    });

    return Scaffold(
      backgroundColor: HpColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1E),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Hyrox group',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? Center(child: Text(_error!))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final mine = message.isCoach;
                          final time = DateTime.tryParse(message.createdAt);
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? HpColors.primary.withValues(alpha: 0.18)
                                    : HpColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: HpColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!mine)
                                    Text(
                                      message.senderName ?? 'Member',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: HpColors.primary,
                                      ),
                                    ),
                                  Text(
                                    message.body,
                                    style: GoogleFonts.inter(fontSize: 14),
                                  ),
                                  if (time != null)
                                    Text(
                                      DateFormat.jm().format(time.toLocal()),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: HpColors.mutedForeground,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message the Hyrox group',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
