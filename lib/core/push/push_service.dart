import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

typedef PushMessageHandler = Future<void> Function(Map<String, String> data);

const _chatChannelId = 'hybrid_pro_admin_chat';
const _chatChannelName = 'Client chat';
const _chatChannelDescription = 'Messages from members';

NotificationDetails _adminNotificationDetails() {
  return const NotificationDetails(
    android: AndroidNotificationDetails(
      _chatChannelId,
      _chatChannelName,
      channelDescription: _chatChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_stat_hybrid',
      largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_launcher_foreground'),
      color: Color(0xFFA0D028),
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );
}

/// Runs when the coach app is closed. Android draws the Hybrid Pro mark here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (kIsWeb || !Platform.isAndroid) return;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}

  final data = message.data.map((key, value) => MapEntry(key, value.toString()));
  // Android already posted this from the FCM notification payload.
  if (message.notification != null || data['systemTray'] == '1') return;

  String pick(List<String?> values, String fallback) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  final title = pick(
    [data['noticeTitle'], message.notification?.title],
    'Hybrid Pro',
  );
  final body = pick(
    [data['noticeBody'], message.notification?.body, data['body']],
    'New update',
  );

  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_hybrid'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  final android = local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(
    const AndroidNotificationChannel(
      _chatChannelId,
      _chatChannelName,
      description: _chatChannelDescription,
      importance: Importance.high,
      playSound: true,
    ),
  );

  final id = ('${data['type']}|${data['messageId']}|$title|$body').hashCode &
      0x7fffffff;
  final payload = data.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  await local.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: _adminNotificationDetails(),
    payload: payload,
  );
}

class PushService {
  PushService({
    required this.registerToken,
    required this.unregisterToken,
    this.onMessage,
    this.onOpened,
  });

  final Future<void> Function(String token, String platform) registerToken;
  final Future<void> Function(String? token) unregisterToken;
  final PushMessageHandler? onMessage;
  final PushMessageHandler? onOpened;

  final _local = FlutterLocalNotificationsPlugin();
  final Set<String> _shownMessageIds = {};
  bool _localsReady = false;
  bool _fcmReady = false;
  String? _token;

  bool get isReady => _localsReady;
  bool get isFcmReady => _fcmReady;
  String? get token => _token;

  Future<void> init() async {
    await _initLocals();
    await _initFcm();
  }

  Future<void> _initLocals() async {
    if (_localsReady) return;

    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_hybrid');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty || onOpened == null) return;
        onOpened!(_decodePayload(payload));
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chatChannelId,
          _chatChannelName,
          description: _chatChannelDescription,
          importance: Importance.high,
          playSound: true,
        ),
      );
      await android?.requestNotificationsPermission();
    }

    if (!kIsWeb && Platform.isIOS) {
      final ios = _local.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _localsReady = true;
  }

  Future<void> _initFcm() async {
    if (_fcmReady) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint(
        'Firebase unavailable (add google-services / Firebase options): $e',
      );
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (!kIsWeb && Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen((message) async {
      final data = _stringData(message.data);
      if (onMessage != null) await onMessage!(data);
      // Member chat tray alerts are owned by AdminSessionServices (suppress when
      // that thread is open). Other push types still surface here.
      if ((data['type'] ?? '') == 'chat.message') return;
      await showIncomingChat(
        title: data['noticeTitle'] ??
            message.notification?.title ??
            data['title'] ??
            'Hybrid Pro Admin',
        body: data['noticeBody'] ??
            message.notification?.body ??
            data['body'] ??
            '',
        data: data,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      if (onOpened != null) await onOpened!(_stringData(message.data));
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null && onOpened != null) {
      await onOpened!(_stringData(initial.data));
    }

    await _syncToken();
    messaging.onTokenRefresh.listen((token) async {
      _token = token;
      await _register(token);
    });

    _fcmReady = true;
  }

  Future<void> startSession() async {
    if (!_localsReady) await _initLocals();
    if (!_fcmReady) await _initFcm();
    if (_fcmReady) await _syncToken();
  }

  Future<void> endSession() async {
    try {
      await unregisterToken(_token);
    } catch (_) {}
    _token = null;
  }

  /// System tray notification with the platform default sound.
  /// Works on iOS Simulator for local/socket alerts. Remote FCM needs a device.
  Future<void> showIncomingChat({
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    if (!_localsReady) await _initLocals();
    if (!_localsReady) return;

    final messageId = data['messageId'] ?? '';
    if (messageId.isNotEmpty) {
      if (_shownMessageIds.contains(messageId)) return;
      _shownMessageIds.add(messageId);
      if (_shownMessageIds.length > 80) {
        _shownMessageIds.remove(_shownMessageIds.first);
      }
    }

    final trimmedBody = body.trim().isEmpty ? 'New message' : body.trim();
    final payload = data.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final id = messageId.isNotEmpty
        ? messageId.hashCode & 0x7fffffff
        : DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

    try {
      await _local.show(
        id: id,
        title: title.trim().isEmpty ? 'New message' : title.trim(),
        body: trimmedBody,
        notificationDetails: _adminNotificationDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Local notification failed: $e');
    }
  }

  Future<void> _syncToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        // Simulator usually has no APNs token — FCM getToken will fail.
        String? apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns == null) {
          await Future<void>.delayed(const Duration(seconds: 2));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apns == null) {
          debugPrint(
            'No APNs token yet (normal on iOS Simulator). '
            'Local chat alerts still work; remote push needs a real device.',
          );
          return;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      await _register(token);
      debugPrint('FCM token registered (${token.substring(0, 12)}…)');
    } catch (e) {
      debugPrint('FCM token failed: $e');
    }
  }

  Future<void> _register(String token) async {
    final platform = !kIsWeb && Platform.isIOS ? 'ios' : 'android';
    try {
      await registerToken(token, platform);
    } catch (e) {
      debugPrint('Device register failed: $e');
    }
  }

  Map<String, String> _stringData(Map<String, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  Map<String, String> _decodePayload(String payload) {
    final data = <String, String>{};
    for (final part in payload.split('&')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      data[Uri.decodeComponent(part.substring(0, i))] =
          Uri.decodeComponent(part.substring(i + 1));
    }
    return data;
  }
}
