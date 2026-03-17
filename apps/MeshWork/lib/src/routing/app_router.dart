import 'package:go_router/go_router.dart';
import 'package:mesh_work/src/pages/splash_page.dart';
import 'package:mesh_work/src/pages/login_page.dart';
import 'package:mesh_work/src/routing/app_shell.dart';
import 'package:ebi_chat/ebi_chat.dart';

/// GoRouter configuration for MeshWork.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => SplashPage(
          onAuthenticated: () => context.go('/home'),
          onUnauthenticated: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          onLoginSuccess: () => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => AppShell(
          onLogout: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/home/chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final roomName = state.uri.queryParameters['name'];
          final unread = int.tryParse(
                state.uri.queryParameters['unread'] ?? '') ?? 0;
          return ChatDetailPage(
            roomId: roomId,
            roomName: roomName,
            initialUnreadCount: unread,
          );
        },
      ),
    ],
  );
}
