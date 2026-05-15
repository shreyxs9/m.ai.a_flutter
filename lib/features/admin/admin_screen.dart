import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Admin',
      subtitle: 'Tenant admin foundation route.',
      icon: Icons.admin_panel_settings_outlined,
    );
  }
}
