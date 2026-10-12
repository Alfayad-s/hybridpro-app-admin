import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/clients/client_detail_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/contacts/contact_detail_screen.dart';
import '../../features/contacts/contacts_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/engagement/engagement_screen.dart';
import '../../features/exercises/exercises_screen.dart';
import '../../features/messages/client_chat_screen.dart';
import '../../features/messages/hyrox_group_screen.dart';
import '../../features/messages/messages_screen.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/sessions/availability_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/admin_shell.dart';
import '../../features/store/products_screen.dart';
import '../../widgets/admin_app_bar.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Do NOT watch auth here — recreating GoRouter resets to /splash and loops.
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final status = auth.status;
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final loggingIn = loc == '/login';

      // Splash owns its own exit after the intro animation.
      if (onSplash) return null;

      if (status == AuthStatus.unknown) {
        return '/splash';
      }
      if (status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }
      if (loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/availability',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: '/engagement',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const EngagementSettingsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) {
          final tag = state.extra is String
              ? state.extra as String
              : adminProfileHeroTag;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: SettingsScreen(heroTag: tag),
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            // Keep the page mostly opaque so Hero can fly above a stable backdrop.
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: Tween<double>(begin: 0.92, end: 1).animate(curved),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/messages',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const MessagesScreen(),
        routes: [
          GoRoute(
            path: 'hyrox',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => const HyroxGroupScreen(),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootKey,
            builder: (context, state) {
              final args = state.extra is ClientChatArgs
                  ? state.extra as ClientChatArgs
                  : null;
              return ClientChatScreen(
                clientId: state.pathParameters['id']!,
                title: args?.title,
                subtitle: args?.subtitle,
                avatarUrl: args?.avatarUrl,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/contacts',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ContactsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => ContactDetailScreen(
              contactId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => ClientDetailScreen(
                      clientId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (context, state) => const ExercisesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payments',
                builder: (context, state) => const PaymentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
