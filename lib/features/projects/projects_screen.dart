import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Projects',
      subtitle: 'Dashboard foundation route.',
      icon: Icons.grid_view_rounded,
    );
  }
}
