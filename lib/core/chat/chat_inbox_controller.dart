import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/admin_repository.dart';
import '../api/chat_models.dart';

final chatInboxProvider =
    NotifierProvider<ChatInboxController, List<ChatInboxItem>>(
  ChatInboxController.new,
);

final adminChatRealtimeProvider =
    NotifierProvider<AdminChatRealtimeController, Map<String, String>?>(
  AdminChatRealtimeController.new,
);

class AdminChatRealtimeController extends Notifier<Map<String, String>?> {
  int _seq = 0;

  @override
  Map<String, String>? build() => null;

  /// Always notifies listeners — Map content equality would drop duplicate typing.
  void publish(Map<String, String> data) {
    _seq += 1;
    state = {
      ...data,
      '_seq': '$_seq',
    };
  }
}

class ChatInboxController extends Notifier<List<ChatInboxItem>> {
  @override
  List<ChatInboxItem> build() => const [];

  Future<void> refresh() async {
    try {
      state = await ref.read(adminRepositoryProvider).chatInbox();
    } catch (_) {}
  }

  void upsertFromRealtime(Map<String, String> data) {
    if ((data['type'] ?? '') != 'chat.message') return;
    final subscriptionId = data['subscriptionId'] ?? '';
    if (subscriptionId.isEmpty) return;
    final message = ChatMessage.fromJson(data);
    final existingIndex =
        state.indexWhere((item) => item.subscriptionId == subscriptionId);
    if (existingIndex < 0) {
      final item = ChatInboxItem(
        conversation: ChatConversation(
          id: data['conversationId'] ?? '',
          subscriptionId: subscriptionId,
          memberUserId: data['memberUserId'] ?? '',
          lastMessageAt: message.createdAt,
          createdAt: message.createdAt,
          unreadCount: message.isMember ? 1 : 0,
        ),
        subscriptionId: subscriptionId,
        email: data['email'] ?? '',
        fullName: data['fullName'],
        lastMessage: message,
      );
      state = [item, ...state];
      return;
    }

    final current = state[existingIndex];
    final unread = message.isMember
        ? current.conversation.unreadCount + 1
        : current.conversation.unreadCount;
    final updated = ChatInboxItem(
      conversation: current.conversation.copyWith(unreadCount: unread),
      subscriptionId: current.subscriptionId,
      email: current.email.isNotEmpty ? current.email : (data['email'] ?? ''),
      fullName: current.fullName ?? data['fullName'],
      lastMessage: message,
    );
    final next = [...state]..removeAt(existingIndex);
    state = [updated, ...next];
  }

  void clearUnread(String subscriptionId) {
    state = [
      for (final item in state)
        if (item.subscriptionId == subscriptionId)
          ChatInboxItem(
            conversation: item.conversation.copyWith(unreadCount: 0),
            subscriptionId: item.subscriptionId,
            email: item.email,
            fullName: item.fullName,
            lastMessage: item.lastMessage,
          )
        else
          item,
    ];
  }
}
