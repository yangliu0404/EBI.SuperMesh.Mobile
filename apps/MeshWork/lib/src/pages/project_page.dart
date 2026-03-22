import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Project page placeholder.
class ProjectPage extends StatelessWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EbiAppBar(title: context.L('Project'), showBack: false),
      body: EbiEmptyState(
        icon: Icons.folder_outlined,
        title: context.L('Project'),
        subtitle: context.L('NoProjectsDescription'),
      ),
    );
  }
}
