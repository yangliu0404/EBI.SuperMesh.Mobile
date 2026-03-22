import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Privacy Policy page for MeshPortal.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _accent = EbiColors.secondaryCyan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EbiColors.bgMeshPortal,
      appBar: EbiAppBar(
        title: context.L('PrivacyPolicy'),
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
                  child: const Icon(Icons.policy_outlined,
                      color: _accent, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  context.L('PrivacyPolicy'),
                  style: EbiTextStyles.h3.copyWith(color: EbiColors.darkNavy),
                ),
                const SizedBox(height: 6),
                Text(
                  context.L('LastUpdatedJanuary2025'),
                  style: EbiTextStyles.bodySmall
                      .copyWith(color: EbiColors.textHint),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Privacy Content Card ──
          EbiCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  '1. Information We Collect',
                  'MeshPortal collects information you provide directly, including your name, email address, phone number, company affiliation, and profile details. We also automatically collect device information, usage data, log files, and analytics to improve our services and provide a better user experience.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '2. How We Use Your Information',
                  'We use collected information to provide and maintain MeshPortal services, personalize your experience, communicate with you about updates and changes, analyze usage patterns to improve functionality, ensure platform security, and comply with legal obligations. We do not sell your personal information to third parties.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '3. Data Storage & Security',
                  'Your data is stored on secure servers with industry-standard encryption both in transit and at rest. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. Regular security audits are conducted to maintain data integrity.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '4. Third-Party Services',
                  'MeshPortal may integrate with third-party services for analytics, crash reporting, and push notifications. These services may collect information in accordance with their own privacy policies. We carefully select partners who maintain high standards of data protection and require them to handle your data responsibly.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '5. Your Rights',
                  'You have the right to access, correct, or delete your personal data at any time. You may request a copy of the data we hold about you, opt out of non-essential data collection, and withdraw consent for data processing. To exercise these rights, please contact us at legal@e-bi.com.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '6. Data Retention',
                  'We retain your personal data only for as long as necessary to fulfill the purposes outlined in this policy, unless a longer retention period is required by law. When data is no longer needed, it is securely deleted or anonymized in accordance with our data retention schedule.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '7. Children\'s Privacy',
                  'MeshPortal is not intended for use by individuals under the age of 16. We do not knowingly collect personal information from children. If we become aware that we have collected data from a child without parental consent, we will take steps to delete that information promptly.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '8. Changes to This Policy',
                  'We may update this Privacy Policy from time to time to reflect changes in our practices or applicable laws. We will notify you of any material changes by posting the updated policy within the application and updating the "Last updated" date. Your continued use of MeshPortal after changes constitutes acceptance of the revised policy.',
                ),
                const Divider(height: 32),
                _buildSection(
                  '9. Contact Us',
                  'If you have any questions or concerns about this Privacy Policy or our data practices, please contact our privacy team at legal@e-bi.com. We are committed to resolving any issues regarding your privacy and personal data.',
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
                        context.L('Questions'),
                        style: EbiTextStyles.labelLarge
                            .copyWith(color: EbiColors.darkNavy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.L('ContactUsAtLegal'),
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
