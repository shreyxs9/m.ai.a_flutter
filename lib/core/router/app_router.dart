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
  final authValue = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const ProjectsScreen()),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) {
          return InviteRedirectScreen(code: state.pathParameters['code'] ?? '');
        },
      ),
      GoRoute(
        path: '/join-workspace/:code',
        builder: (context, state) {
          return WorkspaceJoinScreen(code: state.pathParameters['code'] ?? '');
        },
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) => '/profile/account',
      ),
      GoRoute(
        path: '/profile/:section',
        builder: (context, state) {
          return ProfileScreen(
            section: state.pathParameters['section'] ?? 'account',
          );
        },
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(
        path: '/debug/theme',
        builder: (context, state) => const ThemePreviewScreen(),
      ),
      GoRoute(
        path: '/project/:projectId',
        builder: (context, state) {
          return ChatScreen(projectId: state.pathParameters['projectId'] ?? '');
        },
      ),
      GoRoute(path: '/:path(.*)', redirect: (context, state) => '/'),
    ],
  );
});
