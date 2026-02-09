import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_models/ebi_models.dart';

import 'profile/coming_soon_page.dart';
import 'profile/edit_profile_page.dart';
import 'profile/language_settings_page.dart';
import 'profile/notification_settings_page.dart';
import 'profile/appearance_settings_page.dart';
import 'profile/about_page.dart';
import 'profile/switch_account_sheet.dart';

/// Premium business-style profile page for MeshPortal.
class ProfilePage extends ConsumerWidget {
  final VoidCallback? onLogout;

  const ProfilePage({super.key, this.onLogout});

  static const _accent = EbiColors.secondaryCyan;

  // Height of the curved arc at the bottom of the gradient
  static const _curveHeight = 40.0;
  // How far the stats card pulls up into the gradient
  static const _statsCardHeight = 120.0;
  static const _statsOverlap = 50.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: EbiColors.bgMeshPortal,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Curved Gradient Header + Floating Stats Card ──
            _buildHeaderWithStats(context, user),

            const SizedBox(height: 12),

            // ── PERSONAL ──
            _sectionHeader('PERSONAL'),
            _menuCard(context, [
              _MenuTile(
                icon: Icons.person_outline,
                color: _accent,
                title: 'Edit Profile',
                onTap: () => _push(context, const EditProfilePage()),
              ),
              _MenuTile(
                icon: Icons.qr_code,
                color: _accent,
                title: 'My QR Code',
                onTap: () => _push(
                    context, const ComingSoonPage(title: 'My QR Code')),
              ),
            ]),

            // ── SETTINGS ──
            _sectionHeader('SETTINGS'),
            _menuCard(context, [
              _MenuTile(
                icon: Icons.language,
                color: const Color(0xFF3B82F6),
                title: 'Language',
                trailing: settings.language.label,
                onTap: () =>
                    _push(context, const LanguageSettingsPage()),
              ),
              _MenuTile(
                icon: Icons.notifications_outlined,
                color: const Color(0xFFF59E0B),
                title: 'Notifications',
                onTap: () =>
                    _push(context, const NotificationSettingsPage()),
              ),
              _MenuTile(
                icon: Icons.palette_outlined,
                color: const Color(0xFF8B5CF6),
                title: 'Appearance',
                trailing: settings.appearance.label,
                onTap: () =>
                    _push(context, const AppearanceSettingsPage()),
              ),
              _MenuTile(
                icon: Icons.lock_outline,
                color: const Color(0xFF14B8A6),
                title: 'Privacy',
                onTap: () =>
                    _push(context, const ComingSoonPage(title: 'Privacy')),
              ),
              _MenuTile(
                icon: Icons.storage_outlined,
                color: const Color(0xFF6B7280),
                title: 'Data & Storage',
                onTap: () => _push(
                    context, const ComingSoonPage(title: 'Data & Storage')),
              ),
            ]),

            // ── ACCOUNT & SECURITY ──
            _sectionHeader('ACCOUNT & SECURITY'),
            _menuCard(context, [
              _MenuTile(
                icon: Icons.key_outlined,
                color: const Color(0xFFF59E0B),
                title: 'Change Password',
                onTap: () => _push(
                    context, const ComingSoonPage(title: 'Change Password')),
              ),
              _MenuTile(
                icon: Icons.shield_outlined,
                color: const Color(0xFF22C55E),
                title: 'Security Settings',
                onTap: () => _push(context,
                    const ComingSoonPage(title: 'Security Settings')),
              ),
              _MenuTile(
                icon: Icons.swap_horiz,
                color: const Color(0xFF3B82F6),
                title: 'Switch Account',
                onTap: () => _showSwitchAccount(context, ref),
              ),
              _MenuTile(
                icon: Icons.delete_outline,
                color: const Color(0xFFEF4444),
                title: 'Delete Account',
                onTap: () => _showDeleteAccount(context),
              ),
            ]),

            // ── SUPPORT ──
            _sectionHeader('SUPPORT'),
            _menuCard(context, [
              _MenuTile(
                icon: Icons.help_outline,
                color: _accent,
                title: 'Help Center',
                onTap: () => _push(
                    context, const ComingSoonPage(title: 'Help Center')),
              ),
              _MenuTile(
                icon: Icons.feedback_outlined,
                color: const Color(0xFF8B5CF6),
                title: 'Feedback',
                onTap: () =>
                    _push(context, const ComingSoonPage(title: 'Feedback')),
              ),
              _MenuTile(
                icon: Icons.info_outline,
                color: const Color(0xFF6B7280),
                title: 'About',
                onTap: () => _push(context, const AboutPage()),
              ),
              _MenuTile(
                icon: Icons.description_outlined,
                color: const Color(0xFF14B8A6),
                title: 'Terms of Service',
                onTap: () => _push(context,
                    const ComingSoonPage(title: 'Terms of Service')),
              ),
              _MenuTile(
                icon: Icons.policy_outlined,
                color: const Color(0xFF3B82F6),
                title: 'Privacy Policy',
                onTap: () => _push(
                    context, const ComingSoonPage(title: 'Privacy Policy')),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Sign Out ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EbiColors.error,
                    side: const BorderSide(color: EbiColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _confirmLogout(context, ref),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Version ──
            Center(
              child: Text(
                'MeshPortal v1.0.0',
                style: EbiTextStyles.bodySmall.copyWith(
                  color: EbiColors.textHint,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Curved gradient header + floating stats card ──
  Widget _buildHeaderWithStats(BuildContext context, User? user) {
    final topPadding = MediaQuery.of(context).padding.top;
    const cardOverlap = 50.0;

    return Stack(
      children: [
        Column(
          children: [
            ClipPath(
              clipper: _BottomCurveClipper(_curveHeight),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  topPadding + 20,
                  24,
                  cardOverlap + _curveHeight + 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [EbiColors.darkNavy, _accent],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Avatar ──
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: EbiColors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: EbiAvatar(
                        name: user?.name ?? 'Client',
                        imageUrl: user?.avatar,
                        radius: 30,
                        backgroundColor: _accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ── Name + meta ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.name ?? 'Client Company',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: EbiColors.white,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EbiColors.white
                                      .withValues(alpha: 0.2),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _roleLabel(user?.role),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: EbiColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (user?.email != null)
                            _infoRow(Icons.email_outlined, user!.email),
                          if (user?.phone != null) ...[
                            const SizedBox(height: 3),
                            _infoRow(Icons.phone_outlined, user!.phone!),
                          ],
                          if (user?.company != null) ...[
                            const SizedBox(height: 3),
                            _infoRow(Icons.business_outlined,
                                user!.company!,
                                alpha: 0.6),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 56),
          ],
        ),

        // ── Floating stats card ──
        Positioned(
          left: 20,
          right: 20,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: EbiColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: EbiColors.darkNavy.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _statItem(Icons.inventory_2_outlined, '5', 'Orders',
                    const Color(0xFF3B82F6)),
                _verticalDivider(),
                _statItem(Icons.local_shipping_outlined, '2', 'Shipping',
                    const Color(0xFF22C55E)),
                _verticalDivider(),
                _statItem(Icons.receipt_long_outlined, '3', 'Quotes',
                    const Color(0xFFF59E0B)),
                _verticalDivider(),
                _statItem(Icons.chat_outlined, '7', 'Messages',
                    const Color(0xFF8B5CF6)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: EbiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: EbiTextStyles.labelSmall.copyWith(
              color: EbiColors.textHint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: EbiColors.divider,
    );
  }

  Widget _infoRow(IconData icon, String text, {double alpha = 0.7}) {
    final color = EbiColors.white.withValues(alpha: alpha);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(text, style: EbiTextStyles.bodySmall.copyWith(color: color)),
      ],
    );
  }

  String _roleLabel(UserRole? role) {
    if (role == null) return 'Client';
    final n = role.name;
    return n[0].toUpperCase() + n.substring(1);
  }

  // ── Section header ──
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Text(
        title,
        style: EbiTextStyles.labelSmall.copyWith(
          color: EbiColors.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── Menu card wrapping ListTiles ──
  Widget _menuCard(BuildContext context, List<_MenuTile> tiles) {
    return EbiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: tiles.asMap().entries.map((entry) {
            final index = entry.key;
            final tile = entry.value;
            return Column(
              children: [
                if (index > 0) const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tile.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(tile.icon, color: tile.color, size: 20),
                  ),
                  title: Text(tile.title, style: EbiTextStyles.bodyMedium),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tile.trailing != null)
                        Text(
                          tile.trailing!,
                          style: EbiTextStyles.bodySmall,
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: EbiColors.textHint, size: 20),
                    ],
                  ),
                  onTap: tile.onTap,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Navigation ──
  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // ── Switch Account ──
  void _showSwitchAccount(BuildContext context, WidgetRef ref) {
    ref.read(authProvider.notifier).loadTenants();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const SwitchAccountSheet(),
    );
  }

  // ── Delete Account ──
  void _showDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _push(
                  context, const ComingSoonPage(title: 'Delete Account'));
            },
            style: TextButton.styleFrom(foregroundColor: EbiColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Logout ──
  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              onLogout?.call();
            },
            style: TextButton.styleFrom(foregroundColor: EbiColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// Clips the bottom of a container into a concave curve.
class _BottomCurveClipper extends CustomClipper<Path> {
  final double curveHeight;
  const _BottomCurveClipper(this.curveHeight);

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - curveHeight);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - curveHeight,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _BottomCurveClipper oldClipper) =>
      oldClipper.curveHeight != curveHeight;
}

/// Internal data class for menu tile configuration.
class _MenuTile {
  final IconData icon;
  final Color color;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    this.trailing,
    this.onTap,
  });
}
