import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// About page showing app info and version.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(
        title: 'About',
        backgroundColor: EbiColors.secondaryCyan,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: EbiColors.secondaryCyan,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.portal_outlined,
                color: EbiColors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text('MeshPortal', style: EbiTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: EbiTextStyles.bodyMedium.copyWith(
                color: EbiColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Powered by SuperMesh',
              style: EbiTextStyles.bodySmall.copyWith(
                color: EbiColors.textHint,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\u00a9 2025 e-bi Technology Co. All rights reserved.',
              style: EbiTextStyles.bodySmall.copyWith(
                color: EbiColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
