import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/ebi_chat.dart';
import 'package:mesh_work/src/routing/app_router.dart';

/// Global navigator key shared between GoRouter and CallFloatWindow.
final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Allow self-signed certificates for dev server (10.1.1.8).
  HttpOverrides.global = _DevHttpOverrides();
  runApp(
    ProviderScope(
      overrides: [
        clientIdProvider.overrideWithValue(AppConfig.meshWorkClientId),
      ],
      child: MeshWorkApp(),
    ),
  );
}

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

class MeshWorkApp extends ConsumerStatefulWidget {
  MeshWorkApp({super.key});

  @override
  ConsumerState<MeshWorkApp> createState() => _MeshWorkAppState();
}

class _MeshWorkAppState extends ConsumerState<MeshWorkApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(navigatorKey: rootNavigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state — redirect to login when session expires.
    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final loc = _router.routerDelegate.currentConfiguration.uri.path;
        if (loc != '/' && loc != '/login') {
          _router.go('/login');
        }
      });
    }
    return MaterialApp.router(
      title: 'MeshWork',
      theme: EbiTheme.meshWork(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // Call floating window (shows only when call is minimized)
            CallFloatWindow(navigatorKey: rootNavigatorKey),
          ],
        );
      },
    );
  }
}
