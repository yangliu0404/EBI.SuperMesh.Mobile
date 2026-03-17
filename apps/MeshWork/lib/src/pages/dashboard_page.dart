import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Dashboard page extracted from original main.dart.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'MeshWork', showBack: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.engineering,
              size: 80,
              color: EbiColors.primaryBlue,
            ),
            const SizedBox(height: 24),
            Text('Welcome to MeshWork', style: EbiTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'e-bi Employee Mobile Office',
              style: EbiTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            EbiButton(
              text: 'Get Started',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
