import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Elegant login page with multi-tenant support and third-party login buttons.
class LoginPage extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tenantController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _tenantVerified = false;
  bool _tenantLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tenantController.dispose();
    super.dispose();
  }

  Future<void> _lookupTenant() async {
    final name = _tenantController.text.trim();
    if (name.isEmpty) {
      // Clear tenant — login as Host.
      ref.read(authProvider.notifier).clearTenant();
      setState(() => _tenantVerified = true);
      return;
    }
    setState(() => _tenantLoading = true);
    final tenant =
        await ref.read(authProvider.notifier).findTenantByName(name);
    if (mounted) {
      setState(() {
        _tenantLoading = false;
        _tenantVerified = tenant != null;
      });
      if (tenant != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tenant "${tenant.name}" found'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      widget.onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 40,
                bottom: 40,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    EbiColors.darkNavy,
                    Color(0xFF0D4A6B),
                    EbiColors.primaryBlue,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/ebi_logo.png',
                    width: 160,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SuperMesh',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: EbiColors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'e-bi Specialty Manufacturing',
                    style: TextStyle(
                      fontSize: 13,
                      color: EbiColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Login form
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tenant selector
                    _buildTenantSelector(authState),
                    const SizedBox(height: 20),

                    // Username
                    EbiTextField(
                      controller: _usernameController,
                      hintText: 'Email or Username',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    EbiTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: EbiColors.textHint,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          authState.error!,
                          style: const TextStyle(
                            color: EbiColors.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Sign In button
                    EbiButton(
                      text: 'Sign In',
                      width: double.infinity,
                      isLoading: authState.isLoading,
                      onPressed: authState.isLoading ? null : _login,
                    ),
                    const SizedBox(height: 28),

                    // Divider
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: EbiColors.divider)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or continue with',
                            style: EbiTextStyles.bodySmall
                                .copyWith(color: EbiColors.textHint),
                          ),
                        ),
                        const Expanded(
                            child: Divider(color: EbiColors.divider)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Third-party login buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialButton('Google', Icons.g_mobiledata, const Color(0xFFDB4437)),
                        const SizedBox(width: 16),
                        _socialButton('Apple', Icons.apple, const Color(0xFF000000)),
                        const SizedBox(width: 16),
                        _socialButton('Microsoft', Icons.window, const Color(0xFF00A4EF)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // WeChat button
                    _weChatButton(),
                    const SizedBox(height: 24),

                    // Forgot password
                    Center(
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Password reset coming in Phase 1'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot password?',
                          style: EbiTextStyles.bodySmall.copyWith(
                            color: EbiColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantSelector(AuthState authState) {
    return Row(
      children: [
        Expanded(
          child: EbiTextField(
            controller: _tenantController,
            hintText: 'Tenant Name (empty = Host)',
            prefixIcon: Icons.business,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_tenantVerified) {
                setState(() => _tenantVerified = false);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: EbiButton(
            text: _tenantLoading ? '...' : 'Verify',
            onPressed: _tenantLoading ? null : _lookupTenant,
            isOutlined: _tenantVerified,
          ),
        ),
      ],
    );
  }

  Widget _socialButton(String label, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label login — coming soon'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 52,
        decoration: BoxDecoration(
          color: EbiColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EbiColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: EbiColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weChatButton() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WeChat login — coming soon'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF07C160),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_rounded, color: EbiColors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Continue with WeChat',
              style: TextStyle(
                color: EbiColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
