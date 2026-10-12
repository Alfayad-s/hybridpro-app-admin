import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/admin_repository.dart';
import '../realtime/admin_session_services.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.email,
  });

  final AuthStatus status;
  final String? email;

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const loggedOut = AuthState(status: AuthStatus.unauthenticated);
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restore);
    return AuthState.unknown;
  }

  Future<void> restore() async {
    final store = ref.read(sessionStoreProvider);
    await store.hydrate();
    final token = await store.readToken();
    final email = await store.readEmail();
    if (token != null && token.isNotEmpty) {
      state = AuthState(status: AuthStatus.authenticated, email: email);
      unawaited(ref.read(adminSessionServicesProvider).start());
    } else {
      state = AuthState.loggedOut;
    }
  }

  Future<void> login({required String email, required String password}) async {
    final repo = ref.read(adminRepositoryProvider);
    final store = ref.read(sessionStoreProvider);
    final result = await repo.login(email: email, password: password);
    await store.saveSession(token: result.token, email: result.email);
    state = AuthState(status: AuthStatus.authenticated, email: result.email);
    unawaited(ref.read(adminSessionServicesProvider).start());
  }

  Future<void> logout() async {
    try {
      await ref.read(adminSessionServicesProvider).stop();
    } catch (_) {}
    await ref.read(sessionStoreProvider).clear();
    state = AuthState.loggedOut;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
