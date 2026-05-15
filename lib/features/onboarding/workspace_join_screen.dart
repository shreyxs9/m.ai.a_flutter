import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class WorkspaceJoinScreen extends StatelessWidget {
  const WorkspaceJoinScreen({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Join Workspace',
      subtitle: 'Invite code: $code',
      icon: Icons.apartment_rounded,
    );
  }
}
