import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/ebi_chat.dart';
import 'package:ebi_storage/ebi_storage.dart';
import 'package:mesh_work/src/routing/app_router.dart';

/// Global navigator key shared between GoRouter and CallFloatWindow.
final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow self-signed certificates for dev server (10.1.1.8).
  HttpOverrides.global = _DevHttpOverrides();

  // Initialize local database.
  final db = await AppDatabase.create();

  runApp(
    ProviderScope(
      overrides: [
        clientIdProvider.overrideWithValue(AppConfig.meshWorkClientId),
        databaseProvider.overrideWithValue(db),
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
  bool _localizationInitialized = false;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(navigatorKey: rootNavigatorKey);
    _initSettings();
  }

  Future<void> _initSettings() async {
    // Restore persisted language setting.
    await ref.read(settingsProvider.notifier).init();
    // Load localization immediately (local fallback for login page).
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

    // Reload localization from backend when authenticated (gets full translations).
    if (authState.status == AuthStatus.authenticated &&
        !_localizationInitialized) {
      _localizationInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(localizationProvider.notifier).load();
      });
    } else if (authState.status == AuthStatus.unauthenticated) {
      _localizationInitialized = false;
    }

    // Watch localization state for locale changes.
    final l10n = ref.watch(localizationProvider);

    return LocalizationScope(
      state: l10n,
      child: MaterialApp.router(
        // Force full rebuild when language changes so all pages
        // pick up the new translations immediately.
        key: ValueKey('app_${l10n.currentCulture}'),
        title: 'MeshWork',
        theme: EbiTheme.meshWork(),
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
        builder: (context, child) {
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              // Call floating window (shows only when call is minimized)
              CallFloatWindow(navigatorKey: rootNavigatorKey),
              // Meeting floating window (shows only when meeting is minimized)
              MeetingFloatWindow(navigatorKey: rootNavigatorKey),
              // Language switching loading overlay
              if (l10n.isChanging)
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
        },
      ),
    );
  }
}
