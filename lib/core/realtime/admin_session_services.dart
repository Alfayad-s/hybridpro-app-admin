import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/admin_repository.dart';
import '../api/api_client.dart';
import '../api/gym_models.dart';
import '../chat/chat_inbox_controller.dart';
import '../config/router.dart';
import '../push/push_service.dart';
import 'realtime_client.dart';

final activeGymSessionsProvider =
    NotifierProvider<ActiveGymSessionsController, List<GymSession>>(
  ActiveGymSessionsController.new,
);

class ActiveGymSessionsController extends Notifier<List<GymSession>> {
  @override
  List<GymSession> build() => const [];

  Future<void> refresh() async {
    try {
      final sessions = await ref.read(adminRepositoryProvider).activeGymSessions();
      state = sessions;
    } catch (e) {
      debugPrint('Active gym refresh failed: $e');
    }
  }

  void upsert(GymSession session) {
    final next = [...state.where((s) => s.sessionId != session.sessionId), session];
    next.sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt));
    state = next;
  }

  void removeSession(String sessionId) {
    state = state.where((s) => s.sessionId != sessionId).toList();
  }
}

/// Subscription currently open in client chat — suppress tray noise for that thread.
final activeAdminChatSubscriptionProvider =
    NotifierProvider<_ActiveAdminChatSubscription, String?>(
  _ActiveAdminChatSubscription.new,
);

class _ActiveAdminChatSubscription extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? subscriptionId) => state = subscriptionId;
}

final adminSessionServicesProvider = Provider<AdminSessionServices>((ref) {
  final services = AdminSessionServices(ref);
  ref.onDispose(services.dispose);
  return services;
});

class AdminSessionServices with WidgetsBindingObserver {
  AdminSessionServices(this._ref);

  final Ref _ref;
  PushService? _push;
  HpRealtimeClient? _realtime;
  bool _started = false;
  bool _observing = false;

  HpRealtimeClient? get realtime => _realtime;

  Future<void> start() async {
    if (_started) {
      await _connectRealtime();
      return;
    }
    _started = true;

    _realtime = HpRealtimeClient(onEvent: _onRealtime);
    _push = PushService(
      registerToken: (token, platform) =>
          _ref.read(adminRepositoryProvider).registerDevice(
                token: token,
                platform: platform,
              ),
      unregisterToken: (token) =>
          _ref.read(adminRepositoryProvider).unregisterDevice(token: token),
      onMessage: _onPushData,
      onOpened: _onOpened,
    );

    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    await _push!.init();
    await _push!.startSession();
    await _connectRealtime();
    await _ref.read(activeGymSessionsProvider.notifier).refresh();
    await _ref.read(chatInboxProvider.notifier).refresh();
  }

  Future<void> stop() async {
    await _push?.endSession();
    _realtime?.disconnect();
    _started = false;
  }

  void dispose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _realtime?.disconnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectRealtime();
      _push?.startSession();
    }
  }

  Future<void> _connectRealtime() async {
    final token = await _ref.read(sessionStoreProvider).readToken();
    if (token == null || token.isEmpty) {
      debugPrint('Admin realtime skip: no token');
      return;
    }
    _realtime?.reconnect(token);
  }

  void emitTyping({
    required String subscriptionId,
    required String memberUserId,
    required bool isTyping,
  }) {
    if (memberUserId.isEmpty) return;
    _realtime?.emit('chat.typing', {
      'subscriptionId': subscriptionId,
      'memberUserId': memberUserId,
      'isTyping': isTyping,
    });
  }

  void _onRealtime(String event, Map<String, dynamic> payload) {
    _handleEvent(event, payload.map((k, v) => MapEntry(k, v?.toString() ?? '')));
  }

  Future<void> _onPushData(Map<String, String> data) async {
    final type = data['type'] ?? '';
    if (type.isEmpty) return;
    _handleEvent(type, data);
  }

  Future<void> _onOpened(Map<String, String> data) async {
    await _onPushData(data);
    final route = data['route'];
    final subscriptionId = data['subscriptionId'];
    final target = (route != null && route.isNotEmpty)
        ? route
        : (subscriptionId != null && subscriptionId.isNotEmpty)
            ? '/clients/$subscriptionId'
            : null;
    if (target == null) return;
    try {
      _ref.read(routerProvider).go(target);
    } catch (e) {
      debugPrint('Deep link failed: $e');
    }
  }

  void _handleEvent(String type, Map<String, String> data) {
    if (type == 'hyrox.chat') {
      _ref.read(adminChatRealtimeProvider.notifier).publish(data);
      return;
    }
    if (type.startsWith('chat.')) {
      _ref.read(adminChatRealtimeProvider.notifier).publish(data);
      if (type == 'chat.message') {
        _ref.read(chatInboxProvider.notifier).upsertFromRealtime(data);
        _notifyMemberChat(data);
      }
      return;
    }

    if (type == 'gym.checked_in') {
      final session = GymSession(
        sessionId: data['sessionId'] ?? '',
        subscriptionId: data['subscriptionId'] ?? '',
        userId: data['userId'] ?? '',
        email: data['email'] ?? '',
        fullName: data['fullName'],
        checkedInAt: data['checkedInAt'] ?? DateTime.now().toIso8601String(),
        checkedOutAt: data['checkedOutAt'],
        status: 'open',
      );
      if (session.sessionId.isNotEmpty) {
        _ref.read(activeGymSessionsProvider.notifier).upsert(session);
      }
      return;
    }
    if (type == 'gym.checked_out') {
      final sessionId = data['sessionId'] ?? '';
      if (sessionId.isNotEmpty) {
        _ref.read(activeGymSessionsProvider.notifier).removeSession(sessionId);
      }
    }
  }

  void _notifyMemberChat(Map<String, String> data) {
    if ((data['senderRole'] ?? '') != 'member') return;
    final subscriptionId = data['subscriptionId'] ?? '';
    final active = _ref.read(activeAdminChatSubscriptionProvider);
    if (subscriptionId.isNotEmpty && active == subscriptionId) return;

    final name = (data['fullName'] ?? '').trim();
    final email = (data['email'] ?? '').trim();
    final title = name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Member');
    final body = (data['body'] ?? '').trim();
    final preview = body.isNotEmpty
        ? body
        : ((data['imageUrl'] ?? '').isNotEmpty ? 'Sent a photo' : 'New message');

    _push?.showIncomingChat(title: title, body: preview, data: data);
  }
}
