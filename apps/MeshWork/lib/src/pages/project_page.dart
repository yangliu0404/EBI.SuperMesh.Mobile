import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Project page placeholder.
class ProjectPage extends StatelessWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Project', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.folder_outlined,
        title: 'Project',
        subtitle: 'Your projects will appear here.',
      ),
    );
  }
}
