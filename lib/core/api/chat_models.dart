class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.subscriptionId,
    required this.memberUserId,
    this.lastMessageAt,
    this.memberLastReadAt,
    this.coachLastReadAt,
    required this.createdAt,
    this.unreadCount = 0,
  });

  final String id;
  final String subscriptionId;
  final String memberUserId;
  final String? lastMessageAt;
  final String? memberLastReadAt;
  final String? coachLastReadAt;
  final String createdAt;
  final int unreadCount;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: (json['id'] ?? '').toString(),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      memberUserId: (json['memberUserId'] ?? '').toString(),
      lastMessageAt: json['lastMessageAt']?.toString(),
      memberLastReadAt: json['memberLastReadAt']?.toString(),
      coachLastReadAt: json['coachLastReadAt']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  ChatConversation copyWith({int? unreadCount}) {
    return ChatConversation(
      id: id,
      subscriptionId: subscriptionId,
      memberUserId: memberUserId,
      lastMessageAt: lastMessageAt,
      memberLastReadAt: memberLastReadAt,
      coachLastReadAt: coachLastReadAt,
      createdAt: createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderRole,
    this.senderUserId,
    this.senderName,
    this.senderCoachEmail,
    required this.body,
    this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderRole;
  final String? senderUserId;
  final String? senderName;
  final String? senderCoachEmail;
  final String body;
  final String? imageUrl;
  final String createdAt;

  bool get isCoach => senderRole == 'coach';
  bool get isMember => senderRole == 'member';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? json['messageId'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderRole: (json['senderRole'] ?? 'member').toString(),
      senderUserId: json['senderUserId']?.toString(),
      senderName: json['senderName']?.toString(),
      senderCoachEmail: json['senderCoachEmail']?.toString(),
      body: (json['body'] ?? '').toString(),
      imageUrl: (() {
        final raw = json['imageUrl']?.toString().trim();
        if (raw == null || raw.isEmpty) return null;
        return raw;
      })(),
      createdAt: (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }
}

class ChatThread {
  const ChatThread({
    required this.conversation,
    required this.messages,
  });

  final ChatConversation conversation;
  final List<ChatMessage> messages;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final conv = json['conversation'];
    final list = json['messages'] as List? ?? [];
    return ChatThread(
      conversation: ChatConversation.fromJson(
        conv is Map ? Map<String, dynamic>.from(conv) : {},
      ),
      messages: list
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ChatInboxItem {
  const ChatInboxItem({
    required this.conversation,
    required this.subscriptionId,
    required this.email,
    this.fullName,
    this.lastMessage,
  });

  final ChatConversation conversation;
  final String subscriptionId;
  final String email;
  final String? fullName;
  final ChatMessage? lastMessage;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return 'Member';
  }

  factory ChatInboxItem.fromJson(Map<String, dynamic> json) {
    final conv = json['conversation'];
    final last = json['lastMessage'];
    return ChatInboxItem(
      conversation: ChatConversation.fromJson(
        conv is Map ? Map<String, dynamic>.from(conv) : {},
      ),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: json['fullName']?.toString(),
      lastMessage: last is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(last))
          : null,
    );
  }
}
