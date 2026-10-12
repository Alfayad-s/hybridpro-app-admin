import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

typedef RealtimeHandler = void Function(String event, Map<String, dynamic> payload);

class HpRealtimeClient {
  HpRealtimeClient({this.onEvent});

  final RealtimeHandler? onEvent;

  io.Socket? _socket;
  String? _token;

  bool get connected => _socket?.connected == true;

  void connect(String accessToken) {
    final token = accessToken.trim();
    if (token.isEmpty) return;
    if (_socket != null && _token == token && _socket!.connected) return;

    disconnect();
    _token = token;

    final url = AppConfig.backendUrl.replaceAll(RegExp(r'/$'), '');
    final socket = io.io(
      '$url/realtime',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setQuery({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(800)
          .setReconnectionDelayMax(8000)
          .build(),
    );

    socket.onConnect((_) => debugPrint('Admin realtime connected'));
    socket.onDisconnect((_) => debugPrint('Admin realtime disconnected'));
    socket.onConnectError((e) => debugPrint('Admin realtime error: $e'));
    socket.onError((e) => debugPrint('Admin realtime error: $e'));
    socket.onReconnect((_) => debugPrint('Admin realtime reconnected'));

    for (final event in const [
      'gym.checked_in',
      'gym.checked_out',
      'workout.assigned',
      'workout.updated',
      'workout.unassigned',
      'chat.message',
      'chat.read',
      'chat.typing',
      'hyrox.chat',
    ]) {
      socket.on(event, (data) {
        final payload = _asMap(data);
        payload.putIfAbsent('type', () => event);
        onEvent?.call(event, payload);
      });
    }

    _socket = socket;
    socket.connect();
  }

  void reconnect(String accessToken) {
    final token = accessToken.trim();
    if (token.isEmpty) return;
    if (_socket != null && _token == token && _socket!.connected) return;
    connect(token);
  }

  void emit(String event, Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null) {
      debugPrint('Admin realtime emit skipped (no socket): $event');
      return;
    }
    if (!socket.connected) {
      debugPrint('Admin realtime emit skipped (disconnected): $event');
      return;
    }
    socket.emit(event, data);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _token = null;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }
}
