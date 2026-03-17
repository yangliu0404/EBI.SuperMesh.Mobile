import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Terms of Service page for MeshPortal.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  static const _accent = EbiColors.secondaryCyan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EbiColors.bgMeshPortal,
      appBar: const EbiAppBar(
        title: 'Terms of Service',
        backgroundColor: EbiColors.secondaryCyan,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Header Card ──
          EbiCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: _accent, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Terms of Service',
                  style: EbiTextStyles.h3.copyWith(color: EbiColors.darkNavy),
                ),
                const SizedBox(height: 6),
                Text(
                  'Last updated: January 2025',
                  style: EbiTextStyles.bodySmall
                      .copyWith(color: EbiColors.textHint),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Terms Content Card ──
          EbiCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  '1. Acceptance of Terms',
                  'By accessing and using MeshPortal, you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using or accessing this application. The materials contained in MeshPortal are protected by applicable copyright and trademark law.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '2. Use of Services',
                  'MeshPortal grants you a limited, non-exclusive, non-transferable license to use the application for your internal business purposes. You agree not to reproduce, duplicate, copy, sell, resell, or exploit any portion of the service without express written permission from e-bi Technology Co. You shall not use the service for any unlawful purpose or in violation of any applicable regulations.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '3. User Accounts',
                  'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to notify us immediately of any unauthorized use of your account. MeshPortal reserves the right to suspend or terminate accounts that violate these terms or engage in suspicious activity.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '4. Intellectual Property',
                  'All content, features, and functionality of MeshPortal, including but not limited to text, graphics, logos, icons, images, and software, are the exclusive property of e-bi Technology Co. and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '5. Data Collection',
                  'By using MeshPortal, you consent to the collection and use of information as described in our Privacy Policy. We collect data necessary for providing our services, including but not limited to usage analytics, device information, and user-generated content within the platform.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '6. Limitation of Liability',
                  'In no event shall e-bi Technology Co., its directors, employees, partners, agents, suppliers, or affiliates be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses resulting from your use of MeshPortal.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '7. Termination',
                  'We may terminate or suspend your access to MeshPortal immediately, without prior notice or liability, for any reason, including breach of these Terms. Upon termination, your right to use the service will immediately cease. All provisions of these Terms which by their nature should survive termination shall survive.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '8. Governing Law',
                  'These Terms shall be governed and construed in accordance with the laws of the jurisdiction in which e-bi Technology Co. operates, without regard to its conflict of law provisions. Any disputes arising from these terms will be resolved through binding arbitration in accordance with applicable rules.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '9. Contact Information',
                  'If you have any questions about these Terms of Service, please contact us at legal@e-bi.com. We will make every effort to respond to your inquiry within a reasonable timeframe.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Contact Card ──
          EbiCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.email_outlined, color: _accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Questions?',
                        style: EbiTextStyles.labelLarge
                            .copyWith(color: EbiColors.darkNavy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Contact us at legal@e-bi.com',
                        style: EbiTextStyles.bodySmall
                            .copyWith(color: EbiColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Footer ──
          Center(
            child: Text(
              '\u00a9 2025 e-bi Technology Co. All rights reserved.',
              style: EbiTextStyles.bodySmall.copyWith(
                color: EbiColors.textHint,
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              EbiTextStyles.labelLarge.copyWith(color: EbiColors.darkNavy),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: EbiTextStyles.bodyMedium.copyWith(
            color: EbiColors.textSecondary,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}
