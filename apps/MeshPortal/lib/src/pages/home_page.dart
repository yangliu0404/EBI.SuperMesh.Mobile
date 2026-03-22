import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Home page for MeshPortal client app.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'MeshPortal', showBack: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public,
              size: 80,
              color: EbiColors.primaryBlue,
            ),
            const SizedBox(height: 24),
            Text(context.L('WelcomeToMeshPortal'), style: EbiTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Your Supply Chain at a Glance',
              style: EbiTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            EbiButton(
              text: context.L('ViewProjects'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
