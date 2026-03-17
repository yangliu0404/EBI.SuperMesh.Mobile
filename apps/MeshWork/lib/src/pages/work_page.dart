import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Work page placeholder.
class WorkPage extends StatelessWidget {
  const WorkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Work', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.work_outline,
        title: 'Work',
        subtitle: 'Your work tasks will appear here.',
      ),
    );
  }
}
