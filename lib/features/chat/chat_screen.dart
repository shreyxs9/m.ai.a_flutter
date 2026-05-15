import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Project Chat',
      subtitle: 'Project ID: $projectId',
      icon: Icons.chat_bubble_outline_rounded,
    );
  }
}
