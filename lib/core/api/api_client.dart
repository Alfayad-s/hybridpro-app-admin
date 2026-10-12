import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

const _tokenKey = 'coach_jwt';
const _emailKey = 'coach_email';

class SessionStore {
  SessionStore(this._storage);

  final FlutterSecureStorage _storage;
  String? _tokenMemory;
  String? _emailMemory;
  bool _hydrated = false;

  Future<void> hydrate() async {
    if (_hydrated) return;
    _tokenMemory = await _storage.read(key: _tokenKey);
    _emailMemory = await _storage.read(key: _emailKey);
    _hydrated = true;
  }

  Future<String?> readToken() async {
    await hydrate();
    return _tokenMemory;
  }

  Future<String?> readEmail() async {
    await hydrate();
    return _emailMemory;
  }

  Future<void> saveSession({required String token, required String email}) async {
    _tokenMemory = token;
    _emailMemory = email;
    _hydrated = true;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: email);
  }

  Future<void> clear() async {
    _tokenMemory = null;
    _emailMemory = null;
    _hydrated = true;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SessionStore(const FlutterSecureStorage());
});

final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(sessionStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 12),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Connection': 'keep-alive',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await store.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await store.clear();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String messageFromDio(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final msg = data['message'];
    if (msg is String && msg.isNotEmpty) return msg;
    if (msg is List && msg.isNotEmpty) return msg.join(', ');
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return 'Cannot reach API at ${AppConfig.backendUrl}. '
        'On a physical phone use your Mac LAN IP, not localhost.';
  }
  return e.message ?? 'Request failed';
}
