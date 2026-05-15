import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.section, super.key});

  final String section;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Profile',
      subtitle: 'Section: $section',
      icon: Icons.person_outline_rounded,
    );
  }
}
