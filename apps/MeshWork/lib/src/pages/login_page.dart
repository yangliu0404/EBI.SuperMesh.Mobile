import 'dart:ui';
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
    final tenant = await ref.read(authProvider.notifier).findTenantByName(name);
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

    final success = await ref
        .read(authProvider.notifier)
        .login(
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
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Stack(
        children: [
          // Blurred background blob 1
          Positioned(
            top: -100,
            left: -50,
            width: 400,
            height: 400,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFDBEAFE), // Blue 100
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Blurred background blob 2
          Positioned(
            bottom: -50,
            right: -100,
            width: 500,
            height: 500,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE), // Sky 100
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
              child: Container(color: Colors.transparent),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header Content
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 12),
                    child: _buildLanguageSwitcher(),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Image.asset(
                    'assets/images/ebi_logo.png',
                    width: 140,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),

                // Floating Soft Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04), // ultra soft shadow
                            blurRadius: 40,
                            offset: const Offset(0, -10),
                          )
                        ]
                      ),
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: Text(
                                  'Sign in to SuperMesh',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Tenant selector
                              _buildTenantSelector(authState),
                              const SizedBox(height: 16),

                              // Username
                              _buildSoftTextField(
                                controller: _usernameController,
                                hintText: ref.L('EmailOrUsername'),
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildSoftTextField(
                                controller: _passwordController,
                                hintText: ref.L('Password'),
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
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

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

                              // Glowing Submit Button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 56),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: authState.isLoading ? null : _login,
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 24, height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : Text(
                                          ref.L('SignIn'),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      ref.L('OrContinueWith'),
                                      style: EbiTextStyles.bodySmall.copyWith(
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                    // Third-party login buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialButton(
                          'Google',
                          Icons.g_mobiledata,
                          const Color(0xFFDB4437),
                        ),
                        const SizedBox(width: 16),
                        _socialButton(
                          'Apple',
                          Icons.apple,
                          const Color(0xFF000000),
                        ),
                        const SizedBox(width: 16),
                        _socialButton(
                          'Microsoft',
                          Icons.window,
                          const Color(0xFF00A4EF),
                        ),
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
                              content: Text('Password reset coming in Phase 1'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          ref.L('ForgotPassword'),
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
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantSelector(AuthState authState) {
    return Row(
      children: [
        Expanded(
          child: _buildSoftTextField(
            controller: _tenantController,
            hintText: ref.L('TenantNameHint'),
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
          height: 52, // Match soft input height
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _tenantVerified ? const Color(0xFFF1F5F9) : const Color(0xFF3B82F6),
              foregroundColor: _tenantVerified ? const Color(0xFF0F172A) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            onPressed: _tenantLoading ? null : _lookupTenant,
            child: Text(_tenantLoading ? '...' : ref.L('Verify')),
          ),
        ),
      ],
    );
  }

  Widget _buildSoftTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF1F5F9), // Slate 100
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: EbiColors.error, width: 1),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    final settings = ref.watch(settingsProvider);
    return GestureDetector(
      onTap: () => _showLanguagePicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              settings.language.label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    final l10n = ref.read(localizationProvider);
    final backendLanguages = l10n.languages;
    final currentCulture = ref.read(settingsProvider).language.cultureName;

    // Deduplicate by cultureName.
    final langs = backendLanguages.isNotEmpty
        ? {for (final l in backendLanguages) l.cultureName: l}.values.toList()
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final itemCount = langs?.length ?? AppLanguage.values.length;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.L('Language'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: itemCount,
                    itemBuilder: (_, i) {
                      final String cultureName;
                      final String displayName;
                      if (langs != null) {
                        cultureName = langs[i].cultureName;
                        displayName = langs[i].displayName;
                      } else {
                        cultureName = AppLanguage.values[i].cultureName;
                        displayName = AppLanguage.values[i].label;
                      }
                      return ListTile(
                        title: Text(displayName),
                        subtitle: Text(
                          cultureName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: currentCulture == cultureName
                            ? const Icon(
                                Icons.check,
                                color: EbiColors.primaryBlue,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          ref
                              .read(localizationProvider.notifier)
                              .changeLanguage(cultureName);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Slate 100 
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B), // Slate 500
                fontWeight: FontWeight.w500,
              ),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF07C160).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_rounded, color: Color(0xFF07C160), size: 20),
            const SizedBox(width: 8),
            Text(
              ref.L('ContinueWithWeChat'),
              style: const TextStyle(
                color: Color(0xFF07C160),
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
