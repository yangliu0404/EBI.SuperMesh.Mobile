import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_storage/ebi_storage.dart';
import 'package:mesh_portal/src/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow self-signed certificates for dev server (10.1.1.8).
  HttpOverrides.global = _DevHttpOverrides();

  final db = await AppDatabase.create();

  runApp(
    ProviderScope(
      overrides: [
        clientIdProvider.overrideWithValue(AppConfig.meshPortalClientId),
        databaseProvider.overrideWithValue(db),
      ],
      child: MeshPortalApp(),
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

class MeshPortalApp extends ConsumerStatefulWidget {
  MeshPortalApp({super.key});

  @override
  ConsumerState<MeshPortalApp> createState() => _MeshPortalAppState();
}

class _MeshPortalAppState extends ConsumerState<MeshPortalApp> {
  late final GoRouter _router;
  bool _localizationInitialized = false;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
    _initSettings();
  }

  Future<void> _initSettings() async {
    await ref.read(settingsProvider.notifier).init();
    await ref.read(localizationProvider.notifier).load();
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

    // Reload localization from backend when authenticated.
    if (authState.status == AuthStatus.authenticated &&
        !_localizationInitialized) {
      _localizationInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(localizationProvider.notifier).load();
      });
    } else if (authState.status == AuthStatus.unauthenticated) {
      _localizationInitialized = false;
    }

    final l10n = ref.watch(localizationProvider);

    return LocalizationScope(
      state: l10n,
      child: MaterialApp.router(
        key: ValueKey('app_${l10n.currentCulture}'),
        title: 'MeshPortal',
        theme: EbiTheme.meshPortal(),
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        locale: l10n.isLoaded ? l10n.locale : null,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          Locale('ja'),
          Locale('ko'),
        ],
        builder: l10n.isChanging
            ? (context, child) {
                return Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 32, vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Switching language...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            : null,
      ),
    );
  }
}
