import 'package:go_router/go_router.dart';

import '../../features/admin/admin_screen.dart';
import '../../features/auth/invite_redirect_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/debug/theme_preview_screen.dart';
import '../../features/onboarding/workspace_join_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/projects/projects_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ProjectsScreen(),
    ),
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
      builder: (context, state) => const ProfileScreen(section: 'account'),
      routes: [
        GoRoute(
          path: ':section',
          builder: (context, state) {
            return ProfileScreen(
              section: state.pathParameters['section'] ?? 'account',
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
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
    GoRoute(
      path: '/:path(.*)',
      redirect: (context, state) => '/',
    ),
  ],
);
