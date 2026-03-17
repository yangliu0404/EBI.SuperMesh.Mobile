import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Splash screen for MeshPortal — clean white brand.
class SplashPage extends ConsumerStatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onUnauthenticated;

  const SplashPage({
    super.key,
    required this.onAuthenticated,
    required this.onUnauthenticated,
  });

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final notifier = ref.read(authProvider.notifier);
    await notifier.checkAuthStatus();
    if (!mounted) return;
    final status = ref.read(authProvider).status;
    if (status == AuthStatus.authenticated) {
      widget.onAuthenticated();
    } else {
      widget.onUnauthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              EbiColors.primaryBlue,
              EbiColors.secondaryCyan,
              Color(0xFFE0F7FA),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/ebi_logo.png',
              width: 200,
              height: 90,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'SuperMesh',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: EbiColors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'MeshPortal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: EbiColors.white.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: EbiColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
