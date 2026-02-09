import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Generic placeholder page for features not yet implemented.
class ComingSoonPage extends StatelessWidget {
  final String title;

  const ComingSoonPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EbiAppBar(title: title),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 64,
              color: EbiColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'Coming Soon',
              style: EbiTextStyles.h3.copyWith(color: EbiColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is under development.',
              style: EbiTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
