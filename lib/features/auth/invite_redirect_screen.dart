import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class InviteRedirectScreen extends StatelessWidget {
  const InviteRedirectScreen({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Join Project',
      subtitle: 'Invite code: $code',
      icon: Icons.link_rounded,
    );
  }
}
