import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../models/models.dart';

final projectsProvider = FutureProvider.autoDispose<List<ProjectListItem>>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider).asData?.value;
  final activeTenant = auth?.activeTenant;
  if (activeTenant == null) {
    return const <ProjectListItem>[];
  }

  return ref.watch(projectServiceProvider).list();
});
