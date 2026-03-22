import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

import 'terms_of_service_page.dart';
import 'privacy_policy_page.dart';

/// Premium About page for MeshPortal.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _accent = EbiColors.secondaryCyan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EbiColors.bgMeshPortal,
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──
          SliverToBoxAdapter(child: _buildHeader(context)),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),

                // ── App Info Card ──
                _buildInfoCard(context),

                const SizedBox(height: 16),

                // ── Features Card ──
                _buildFeaturesCard(context),

                const SizedBox(height: 16),

                // ── Tech & Legal Card ──
                _buildLegalCard(context),

                const SizedBox(height: 32),

                // ── Footer ──
                _buildFooter(context),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gradient Header with Logo ──
  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EbiColors.darkNavy, _accent],
        ),
      ),
      child: Column(
        children: [
          // ── Back Button ──
          Padding(
            padding: EdgeInsets.only(top: topPadding, left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: EbiColors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Logo ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EbiColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Image.asset(
              'assets/images/ebi_logo.png',
              width: 120,
              height: 54,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 20),

          // ── App Name ──
          const Text(
            'MeshPortal',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: EbiColors.white,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 6),

          // ── Tagline ──
          Text(
            context.L('ClientCollaborationPortal'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: EbiColors.white.withValues(alpha: 0.75),
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 16),

          // ── Version Badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: EbiColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'v1.0.0 (Build 1)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: EbiColors.white,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── App Info Card ──
  Widget _buildInfoCard(BuildContext context) {
    return EbiCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                context.L('AboutMeshPortal'),
                style: EbiTextStyles.h3.copyWith(color: EbiColors.darkNavy),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'MeshPortal is a client-facing collaboration portal by e-bi International. '
            'It provides clients with transparent order tracking, real-time quotation management, '
            'and seamless communication — delivering a premium business partnership experience.',
            style: EbiTextStyles.bodyMedium.copyWith(
              color: EbiColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Features Card ──
  Widget _buildFeaturesCard(BuildContext context) {
    return EbiCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_outlined,
                    color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                context.L('KeyFeatures'),
                style: EbiTextStyles.h3.copyWith(color: EbiColors.darkNavy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _featureItem(
            Icons.inventory_2_outlined,
            const Color(0xFF3B82F6),
            context.L('OrderTracking'),
            context.L('OrderTrackingDescription'),
          ),
          _featureItem(
            Icons.receipt_long_outlined,
            const Color(0xFFF59E0B),
            context.L('QuotationManagement'),
            context.L('QuotationManagementDescription'),
          ),
          _featureItem(
            Icons.chat_outlined,
            const Color(0xFF22C55E),
            context.L('DirectCommunication'),
            context.L('DirectCommunicationDescription'),
          ),
          _featureItem(
            Icons.language,
            const Color(0xFF14B8A6),
            context.L('MultiLanguageSupport'),
            context.L('MultiLanguageSupportDescription'),
          ),
          _featureItem(
            Icons.security_outlined,
            const Color(0xFFEF4444),
            context.L('EnterpriseSecurity'),
            context.L('EnterpriseSecurityDescription'),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _featureItem(
    IconData icon,
    Color color,
    String title,
    String subtitle, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: EbiTextStyles.labelLarge.copyWith(
                    color: EbiColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: EbiTextStyles.bodySmall.copyWith(
                    color: EbiColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Legal Card ──
  Widget _buildLegalCard(BuildContext context) {
    return EbiCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _legalTile(
            Icons.description_outlined,
            const Color(0xFF14B8A6),
            context.L('TermsOfService'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _legalTile(
            Icons.policy_outlined,
            const Color(0xFF3B82F6),
            context.L('PrivacyPolicy'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legalTile(
    IconData icon,
    Color color,
    String title, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: EbiTextStyles.bodyMedium),
      trailing: const Icon(Icons.chevron_right,
          color: EbiColors.textHint, size: 20),
      onTap: onTap,
    );
  }

  // ── Footer ──
  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        // ── Powered By ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 1,
              color: EbiColors.divider,
            ),
            const SizedBox(width: 12),
            Text(
              context.L('PoweredBySuperMesh'),
              style: EbiTextStyles.labelSmall.copyWith(
                color: EbiColors.textHint,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 1,
              color: EbiColors.divider,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '\u00a9 2025 e-bi Technology Co. All rights reserved.',
          style: EbiTextStyles.bodySmall.copyWith(
            color: EbiColors.textHint,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Made with \u2764 for business partners',
          style: EbiTextStyles.bodySmall.copyWith(
            color: EbiColors.textHint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
