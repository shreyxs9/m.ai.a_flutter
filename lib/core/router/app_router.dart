import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/auth/invite_redirect_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/debug/theme_preview_screen.dart';
import '../../features/onboarding/workspace_join_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/projects/projects_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRouteRefresh(ref);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authValue = authRefresh.authValue;
      final auth = authValue.asData?.value;
      final loading = authValue.isLoading || (auth?.loading ?? true);
      if (loading) {
        return null;
      }

      final authenticated = auth?.isAuthenticated ?? false;
      final onLogin = state.matchedLocation == '/login';
      final onWelcome = state.matchedLocation == '/welcome';
      final onInvite = state.matchedLocation.startsWith('/join/');
      final onWorkspaceInvite = state.matchedLocation.startsWith(
        '/join-workspace/',
      );

      if (!authenticated &&
          !onLogin &&
          !onWelcome &&
          !onInvite &&
          !onWorkspaceInvite) {
        return '/login';
      }
      if (authenticated && (onLogin || onWelcome)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => _routePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _routePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _routePage(state, const ProjectsScreen()),
      ),
      GoRoute(
        path: '/join/:code',
        pageBuilder: (context, state) => _routePage(
          state,
          InviteRedirectScreen(code: state.pathParameters['code'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/join-workspace/:code',
        pageBuilder: (context, state) => _routePage(
          state,
          WorkspaceJoinScreen(code: state.pathParameters['code'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) => '/profile/account',
      ),
      GoRoute(
        path: '/profile/:section',
        pageBuilder: (context, state) {
          return _routePage(
            state,
            ProfileScreen(
              section: state.pathParameters['section'] ?? 'account',
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => _routePage(state, const AdminScreen()),
      ),
      GoRoute(
        path: '/debug/theme',
        pageBuilder: (context, state) =>
            _routePage(state, const ThemePreviewScreen()),
      ),
      GoRoute(
        path: '/project/:projectId',
        pageBuilder: (context, state) => _routePage(
          state,
          ChatScreen(projectId: state.pathParameters['projectId'] ?? ''),
        ),
      ),
      GoRoute(path: '/:path(.*)', redirect: (context, state) => '/'),
    ],
  );
});

class _AuthRouteRefresh extends ChangeNotifier {
  _AuthRouteRefresh(this._ref) {
    _subscription = _ref.listen(authControllerProvider, (previous, next) {
      _authValue = next;
      notifyListeners();
    }, fireImmediately: true);
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AuthState>> _subscription;
  AsyncValue<AuthState> _authValue = const AsyncLoading<AuthState>();

  AsyncValue<AuthState> get authValue => _authValue;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

CustomTransitionPage<void> _routePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 110),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.015, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
