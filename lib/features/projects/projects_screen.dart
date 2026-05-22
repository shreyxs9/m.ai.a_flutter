import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/models.dart';
import 'project_avatar_widget.dart';
import 'project_icon_registry.dart';
import 'projects_provider.dart';

const _roleOptions = <String>[
  'Founder / Exec',
  'Product Manager',
  'Engineering Manager',
  'Software Engineer',
  'Designer',
  'Data / Analytics',
  'Marketing',
  'Sales',
  'Customer Success',
  'Operations',
  'People / HR',
];

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authControllerProvider);
    final auth = authValue.asData?.value;

    if (authValue.isLoading || (auth?.loading ?? true)) {
      return const Scaffold(body: Center(child: _MaiaMark(animate: true)));
    }

    if (auth?.isAuthenticated == true && auth!.tenants.isEmpty) {
      return EmptyDashboardScreen(user: auth.user!);
    }

    return _ProjectsDashboard(auth: auth);
  }
}

class _ProjectsDashboard extends ConsumerStatefulWidget {
  const _ProjectsDashboard({required this.auth});

  final AuthState? auth;

  @override
  ConsumerState<_ProjectsDashboard> createState() => _ProjectsDashboardState();
}

class _ProjectsDashboardState extends ConsumerState<_ProjectsDashboard> {
  late final String _greeting = _pickGreeting();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final textTheme = Theme.of(context).textTheme;
    final projectsValue = ref.watch(projectsProvider);
    final projects = projectsValue.asData?.value ?? const <ProjectListItem>[];
    final totalBlockers = projects.fold<int>(
      0,
      (sum, project) => sum + project.blockerCount,
    );

    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DashboardHeader(auth: widget.auth),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting.',
                          style: textTheme.displaySmall?.copyWith(
                            color: tokens.text,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          totalBlockers > 0
                              ? '$totalBlockers blocker${totalBlockers == 1 ? '' : 's'} waiting on you today.'
                              : 'No open blockers. Maia will check in at your scheduled time.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: tokens.dim,
                            fontStyle: FontStyle.italic,
                            fontFamily: Theme.of(
                              context,
                            ).textTheme.titleLarge?.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refreshProjects(ref),
                    color: tokens.accent,
                    backgroundColor: tokens.backgroundRaised,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          sliver: SliverToBoxAdapter(
                            child: _ProjectsToolbar(
                              count: projects.length,
                              loading: projectsValue.isLoading,
                              onRefresh: () => _refreshProjects(ref),
                              onJoin: _showJoinProjectSheet,
                              onCreate: _showCreateProjectSheet,
                            ),
                          ),
                        ),
                        projectsValue.when(
                          data: (items) {
                            if (items.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: _WorkspaceEmptyProjects(
                                  onCreate: _showCreateProjectSheet,
                                  onJoin: _showJoinProjectSheet,
                                ),
                              );
                            }
                            return SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              sliver: SliverLayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = _gridColumns(
                                    constraints.crossAxisExtent,
                                  );
                                  return SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: columns == 1
                                              ? 3.3
                                              : 2.7,
                                        ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _ProjectCard(
                                        project: items[index],
                                        onTap: () => context.go(
                                          '/project/${items[index].id}',
                                        ),
                                      ),
                                      childCount: items.length,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          loading: () => const SliverFillRemaining(
                            child: Center(child: _MaiaMark(animate: true)),
                          ),
                          error: (error, _) => SliverFillRemaining(
                            hasScrollBody: false,
                            child: _ErrorState(
                              message: _messageFor(error),
                              onRetry: () => ref.invalidate(projectsProvider),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshProjects(WidgetRef ref) async {
    ref.invalidate(projectsProvider);
    await ref.read(projectsProvider.future);
  }

  Future<void> _showCreateProjectSheet() async {
    final project = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateProjectSheet(),
    );
    if (!mounted || project == null) {
      return;
    }
    ref.invalidate(projectsProvider);
    context.go('/project/${project.id}');
  }

  Future<void> _showJoinProjectSheet() async {
    final result = await showModalBottomSheet<JoinByInviteResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const JoinProjectSheet(),
    );
    if (!mounted || result == null) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .selectTenantId(result.tenantId);
    await ref.read(authControllerProvider.notifier).refreshTenants();
    ref.invalidate(projectsProvider);
    if (mounted) {
      context.go('/project/${result.projectId}');
    }
  }
}

class EmptyDashboardScreen extends ConsumerStatefulWidget {
  const EmptyDashboardScreen({required this.user, super.key});

  final User user;

  @override
  ConsumerState<EmptyDashboardScreen> createState() =>
      _EmptyDashboardScreenState();
}

class _EmptyDashboardScreenState extends ConsumerState<EmptyDashboardScreen> {
  String _mode = 'chooser';
  final _workspaceController = TextEditingController();
  final _customRoleController = TextEditingController();
  final _inviteController = TextEditingController();
  String _role = '';
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _workspaceController.dispose();
    _customRoleController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final firstName =
        widget.user.name.split(' ').firstOrNull ?? widget.user.name;

    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: tokens.accentSurfaceDecoration(),
                          child: const Center(child: _MaiaMark(size: 28)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome, $firstName',
                        textAlign: TextAlign.center,
                        style: _eyebrowStyle(context),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "You're not in any workspace yet.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w300),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create one, or join with an invite link.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.dim,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_mode == 'chooser') _buildChooser(context),
                      if (_mode == 'create') _buildCreate(context),
                      if (_mode == 'join') _buildJoin(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooser(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () => setState(() => _mode = 'create'),
          child: const Text('Create a workspace'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => setState(() => _mode = 'join'),
          child: const Text('I have an invite link'),
        ),
      ],
    );
  }

  Widget _buildCreate(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel('Workspace name'),
        TextField(
          controller: _workspaceController,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'e.g. Acme',
            counterText: '',
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Your role'),
        _RolePicker(
          value: _role,
          customController: _customRoleController,
          onChanged: (value) => setState(() {
            _role = value;
            _error = null;
          }),
        ),
        if (_error != null) _InlineError(_error!),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : _backToChooser,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _submitting ? null : _createWorkspace,
                child: Text(_submitting ? 'Creating...' : 'Create'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoin(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel('Invite link or code'),
        TextField(
          controller: _inviteController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'A3K9XZ'),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _continueInvite(),
        ),
        if (_error != null) _InlineError(_error!),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _backToChooser,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _continueInvite,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _backToChooser() {
    setState(() {
      _mode = 'chooser';
      _error = null;
      _submitting = false;
    });
  }

  Future<void> _createWorkspace() async {
    final name = _workspaceController.text.trim();
    final role = _resolvedRole();
    final validation = _validateWorkspace(name, role);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final tenant = await ref.read(tenantServiceProvider).create(name);
      if (tenant == null) {
        throw const ApiException(null, "Couldn't create workspace");
      }
      try {
        await ref.read(authServiceProvider).updateTitle(role);
      } catch (_) {}
      await ref.read(authControllerProvider.notifier).refreshTenants();
      await ref.read(authControllerProvider.notifier).switchTenant(tenant);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _messageFor(error);
          _submitting = false;
        });
      }
    }
  }

  void _continueInvite() {
    final code = _extractInviteCode(_inviteController.text);
    if (code == null || code.length != 6) {
      setState(() => _error = 'Enter the 6-character invite code');
      return;
    }
    context.go('/join-workspace/$code');
  }

  String _resolvedRole() {
    if (_role == '__custom') {
      return _customRoleController.text.trim();
    }
    return _role.trim();
  }
}

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({required this.auth});

  final AuthState? auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTenant = auth?.activeTenant;
    final tenants = auth?.tenants ?? const <Tenant>[];
    final user = auth?.user;
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          const _MaiaMark(size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              today.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _eyebrowStyle(context),
            ),
          ),
          if (activeTenant != null)
            OrgSwitcherMenu(activeTenant: activeTenant, tenants: tenants),
          const SizedBox(width: 8),
          if (user != null) _UserPill(user: user),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Appearance',
            onPressed: () =>
                ref.read(themeControllerProvider.notifier).toggleMode(),
            icon: const Icon(Icons.palette_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class OrgSwitcherMenu extends ConsumerWidget {
  const OrgSwitcherMenu({
    required this.activeTenant,
    required this.tenants,
    super.key,
  });

  final Tenant activeTenant;
  final List<Tenant> tenants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.maia;

    return PopupMenuButton<String>(
      tooltip: 'Workspace',
      color: tokens.backgroundRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        side: BorderSide(color: tokens.border),
      ),
      onSelected: (value) async {
        if (value == '__create') {
          final tenant = await showModalBottomSheet<Tenant>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const CreateWorkspaceSheet(),
          );
          if (tenant != null) {
            await ref.read(authControllerProvider.notifier).refreshTenants();
            await ref
                .read(authControllerProvider.notifier)
                .switchTenant(tenant);
            ref.invalidate(projectsProvider);
          }
          return;
        }
        final tenant = tenants.firstWhere((tenant) => tenant.id == value);
        await ref.read(authControllerProvider.notifier).switchTenant(tenant);
        ref.invalidate(projectsProvider);
      },
      itemBuilder: (context) => [
        for (final tenant in tenants)
          PopupMenuItem<String>(
            value: tenant.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tenant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tenant.id == activeTenant.id)
                  Icon(Icons.check_rounded, color: tokens.accent, size: 18),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__create',
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 18),
              SizedBox(width: 8),
              Text('Create new workspace'),
            ],
          ),
        ),
      ],
      child: Container(
        height: 34,
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: tokens.surfaceDecoration(
          color: tokens.backgroundCard,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                activeTenant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: tokens.dim, size: 16),
          ],
        ),
      ),
    );
  }
}

class CreateWorkspaceSheet extends ConsumerStatefulWidget {
  const CreateWorkspaceSheet({super.key});

  @override
  ConsumerState<CreateWorkspaceSheet> createState() =>
      _CreateWorkspaceSheetState();
}

class _CreateWorkspaceSheetState extends ConsumerState<CreateWorkspaceSheet> {
  final _nameController = TextEditingController();
  final _customRoleController = TextEditingController();
  String _role = '';
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _customRoleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Create a new workspace',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FieldLabel('Workspace name'),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: 'e.g. Acme',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Your role'),
          _RolePicker(
            value: _role,
            customController: _customRoleController,
            onChanged: (value) => setState(() {
              _role = value;
              _error = null;
            }),
          ),
          if (_error != null) _InlineError(_error!),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final role = _role == '__custom'
        ? _customRoleController.text.trim()
        : _role;
    final validation = _validateWorkspace(name, role);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final tenant = await ref.read(tenantServiceProvider).create(name);
      if (tenant == null) {
        throw const ApiException(null, "Couldn't create workspace");
      }
      try {
        await ref.read(authServiceProvider).updateTitle(role);
      } catch (_) {}
      if (mounted) {
        context.pop(tenant);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _messageFor(error);
          _submitting = false;
        });
      }
    }
  }
}

class CreateProjectSheet extends ConsumerStatefulWidget {
  const CreateProjectSheet({super.key});

  @override
  ConsumerState<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends ConsumerState<CreateProjectSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _icon;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'New project',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FieldLabel('Icon'),
          _ProjectIconPicker(
            value: _icon,
            onChanged: (value) => setState(() => _icon = value),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Name'),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'e.g. Q4 Product Launch',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Description'),
          TextField(
            controller: _descriptionController,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "What's this project about?",
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) _InlineError(_error!),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final validation = _validateProject(name, description);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final project = await ref
          .read(projectServiceProvider)
          .create(
            name: name,
            description: description.isEmpty ? null : description,
            icon: _icon,
          );
      if (project == null) {
        throw const ApiException(null, "Couldn't create project");
      }
      if (mounted) {
        context.pop(project);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _messageFor(error);
          _submitting = false;
        });
      }
    }
  }
}

class JoinProjectSheet extends ConsumerStatefulWidget {
  const JoinProjectSheet({super.key});

  @override
  ConsumerState<JoinProjectSheet> createState() => _JoinProjectSheetState();
}

class _JoinProjectSheetState extends ConsumerState<JoinProjectSheet> {
  final _codeController = TextEditingController();
  String? _error;
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Join a project',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FieldLabel('Invite code'),
          TextField(
            controller: _codeController,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            ],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              letterSpacing: 3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: const InputDecoration(
              hintText: 'A3K9XZ',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) _InlineError(_error!),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _joining ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _joining ? null : _submit,
                  child: Text(_joining ? 'Joining...' : 'Join'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final code = _normalizeInviteCode(_codeController.text);
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-character invite code');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final result = await ref.read(projectServiceProvider).joinByInvite(code);
      if (result == null) {
        throw const ApiException(null, "Code didn't match any project");
      }
      if (result.alreadyMember) {
        setState(() {
          _error =
              "You're already a member of ${result.projectName}. Open it from the projects list.";
          _joining = false;
        });
        return;
      }
      if (mounted) {
        context.pop(result);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _messageFor(error);
          _joining = false;
        });
      }
    }
  }
}

class _ProjectsToolbar extends StatelessWidget {
  const _ProjectsToolbar({
    required this.count,
    required this.loading,
    required this.onRefresh,
    required this.onJoin,
    required this.onCreate,
  });

  final int count;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Row(
      children: [
        Text('YOUR PROJECTS', style: _eyebrowStyle(context)),
        if (count > 0) ...[
          const SizedBox(width: 10),
          Text(
            '$count',
            style: _eyebrowStyle(context).copyWith(color: tokens.faint),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(child: Divider(color: tokens.border)),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
        ),
        OutlinedButton.icon(
          onPressed: onJoin,
          icon: const Icon(Icons.link_rounded, size: 16),
          label: const Text('Join'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('New project'),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final ProjectListItem project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final hasBlockers = project.blockerCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: tokens
              .surfaceDecoration(
                borderRadius: BorderRadius.circular(tokens.radius),
                withShadow: true,
              )
              .copyWith(
                border: Border.all(
                  color: hasBlockers
                      ? tokens.danger.withValues(alpha: 0.34)
                      : tokens.border,
                ),
              ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProjectAvatarWidget(
                code: project.code,
                icon: project.icon,
                accent: project.accentColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (project.lastMessageTs != null)
                          Text(
                            DateFormat('MMM d').format(project.lastMessageTs!),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.faint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      project.description.isEmpty
                          ? 'No description'
                          : project.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.dim),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _MemberStack(members: project.memberPreviews),
                        const SizedBox(width: 8),
                        Text(
                          '${project.memberCount} member${project.memberCount == 1 ? '' : 's'}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: tokens.faint),
                        ),
                        const Spacer(),
                        if (hasBlockers)
                          _BlockerBadge(count: project.blockerCount),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberStack extends StatelessWidget {
  const _MemberStack({required this.members});

  final List<ProjectMemberPreview> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }
    final visible = members.take(4).toList(growable: false);
    return SizedBox(
      width: 18 + (visible.length - 1) * 13,
      height: 18,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 13,
              child: _TinyAvatar(member: visible[i]),
            ),
        ],
      ),
    );
  }
}

class _TinyAvatar extends StatelessWidget {
  const _TinyAvatar({required this.member});

  final ProjectMemberPreview member;

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(member.name);
    final initial = member.name.trim().isEmpty ? '?' : member.name.trim()[0];

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: context.maia.background, width: 1),
      ),
      child: Text(
        initial.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BlockerBadge extends StatelessWidget {
  const _BlockerBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: tokens.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 12, color: tokens.danger),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectIconPicker extends StatelessWidget {
  const _ProjectIconPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final icon = ProjectIconRegistry.resolve(value);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: Icon(icon ?? Icons.category_outlined, size: 18),
          label: Text(value == null ? 'Pick an icon' : 'Change icon'),
          onPressed: () => _showIconPicker(context),
        ),
        if (value != null)
          ActionChip(
            label: const Text('Use initials'),
            onPressed: () => onChanged(null),
          ),
        if (value != null)
          ProjectAvatarWidget(
            code: 'MA',
            icon: value,
            accent: _hex(tokens.accent),
            size: 34,
            radius: 9,
          ),
      ],
    );
  }

  Future<void> _showIconPicker(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => _ProjectIconDialog(selected: value),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}

class _ProjectIconDialog extends StatefulWidget {
  const _ProjectIconDialog({required this.selected});

  final String? selected;

  @override
  State<_ProjectIconDialog> createState() => _ProjectIconDialogState();
}

class _ProjectIconDialogState extends State<_ProjectIconDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final query = _query.trim().toLowerCase();
    final categories = query.isEmpty
        ? ProjectIconRegistry.categories
        : <ProjectIconCategory>[
            ProjectIconCategory(
              label: 'Matches',
              keys: ProjectIconRegistry.keys
                  .where((key) => key.toLowerCase().contains(query))
                  .toList(growable: false),
            ),
          ];

    return AlertDialog(
      backgroundColor: tokens.backgroundRaised,
      title: const Text('Project icon'),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search icons',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final category in categories) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(
                        category.label,
                        style: _eyebrowStyle(context),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final key in category.keys)
                          _IconChoice(
                            iconKey: key,
                            selected: key == widget.selected,
                            onTap: () => context.pop(key),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.iconKey,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Tooltip(
      message: iconKey.replaceAll('-', ' '),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: selected ? tokens.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? tokens.accent : Colors.transparent,
            ),
          ),
          child: Icon(
            ProjectIconRegistry.resolve(iconKey),
            color: selected ? tokens.accent : tokens.text,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.value,
    required this.customController,
    required this.onChanged,
  });

  final String value;
  final TextEditingController customController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final role in _roleOptions)
              ChoiceChip(
                label: Text(role),
                selected: value == role,
                onSelected: (_) => onChanged(role),
              ),
            ChoiceChip(
              label: const Text('Something else'),
              selected: value == '__custom',
              onSelected: (_) => onChanged('__custom'),
            ),
          ],
        ),
        if (value == '__custom') ...[
          const SizedBox(height: 10),
          TextField(
            controller: customController,
            maxLength: 64,
            decoration: const InputDecoration(
              hintText: 'e.g. Chief of Staff',
              counterText: '',
            ),
          ),
        ],
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: width >= 720 ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: width >= 720 ? const EdgeInsets.all(24) : EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: tokens.backgroundRaised,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(tokens.radius + 8),
                bottom: width >= 720
                    ? Radius.circular(tokens.radius + 8)
                    : Radius.zero,
              ),
              border: Border.all(color: tokens.border),
              boxShadow: tokens.shadowHover,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.faint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceEmptyProjects extends StatelessWidget {
  const _WorkspaceEmptyProjects({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            decoration: tokens.surfaceDecoration(withShadow: true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: tokens.accentSurfaceDecoration(),
                  child: Icon(Icons.grid_view_rounded, color: tokens.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'No projects yet.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a project, or join one with an invite code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.dim),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onJoin,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Join'),
                    ),
                    FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New project'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            decoration: tokens.dangerSurfaceDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: tokens.danger),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.danger),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label.toUpperCase(), style: _eyebrowStyle(context)),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.maia.danger),
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  const _UserPill({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final first = user.name.split(' ').firstOrNull ?? user.name;
    return InkWell(
      onTap: () => context.go('/profile'),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 4, right: 10),
        decoration: tokens.surfaceDecoration(
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            _PersonAvatar(user: user),
            const SizedBox(width: 7),
            Text(
              first,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final color = _avatarColor(user.name);

    return CircleAvatar(
      radius: 12,
      backgroundColor: color.withValues(alpha: 0.18),
      foregroundImage: user.avatarUrl == null
          ? null
          : NetworkImage(user.avatarUrl!),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _MaiaMark extends StatefulWidget {
  const _MaiaMark({this.size = 28, this.animate = false});

  final double size;
  final bool animate;

  @override
  State<_MaiaMark> createState() => _MaiaMarkState();
}

class _MaiaMarkState extends State<_MaiaMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final mark = Icon(
      Icons.auto_awesome_rounded,
      size: widget.size,
      color: tokens.accent,
    );
    if (!widget.animate) {
      return mark;
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: mark,
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.55, -0.7),
            radius: 1.0,
            colors: [
              tokens.accent.withValues(alpha: tokens.isDark ? 0.08 : 0.12),
              tokens.background,
            ],
            stops: const [0, 0.72],
          ),
        ),
      ),
    );
  }
}

int _gridColumns(double width) {
  if (width < 640) {
    return 1;
  }
  if (width < 1024) {
    return 2;
  }
  if (width < 1440) {
    return 3;
  }
  return 4;
}

String _pickGreeting() {
  final hour = DateTime.now().hour;
  final pool = hour < 5
      ? ['Hey, night owl', 'Hope you are doing well', 'Welcome back']
      : hour < 12
      ? ['Good morning', 'Fresh start today', 'Welcome back']
      : hour < 17
      ? ['Good afternoon', 'Hope your day is going well', 'Hey there']
      : hour < 21
      ? ['Good evening', 'Hope you had a great day', 'Welcome back']
      : ['Hey there', 'Good evening', 'Glad you are here'];
  return pool[DateTime.now().millisecond % pool.length];
}

String? _validateProject(String name, String description) {
  if (name.trim().isEmpty) {
    return 'Project name is required';
  }
  if (name.trim().length > 200) {
    return 'Project name must be 200 characters or fewer';
  }
  if (description.trim().length > 1000) {
    return 'Description must be 1000 characters or fewer';
  }
  return null;
}

String? _validateWorkspace(String name, String role) {
  if (name.trim().isEmpty) {
    return 'Workspace name is required';
  }
  if (name.trim().length > 100) {
    return 'Workspace name must be 100 characters or fewer';
  }
  if (role.trim().isEmpty) {
    return 'Role is required';
  }
  if (role.trim().length > 64) {
    return 'Custom role must be 64 characters or fewer';
  }
  return null;
}

String _normalizeInviteCode(String value) {
  return value.trim().toUpperCase();
}

String? _extractInviteCode(String value) {
  final match = RegExp(r'([A-Za-z0-9]{6})/?$').firstMatch(value.trim());
  return match?.group(1)?.toUpperCase();
}

String _messageFor(Object error) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Request failed. Please try again.';
}

TextStyle _eyebrowStyle(BuildContext context) {
  final tokens = context.maia;
  return Theme.of(context).textTheme.labelSmall?.copyWith(
        color: tokens.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ) ??
      TextStyle(color: tokens.faint, fontWeight: FontWeight.w800);
}

Color _avatarColor(String name) {
  const colors = <Color>[
    Color(0xFFE4A866),
    Color(0xFF5FB8A8),
    Color(0xFFB6C49A),
    Color(0xFFD88A7A),
    Color(0xFFA78BCD),
    Color(0xFF7EC99A),
    Color(0xFFE0826E),
    Color(0xFF6BB5D9),
    Color(0xFFC4A35A),
    Color(0xFF8BC4B0),
  ];
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = unit + ((hash << 5) - hash);
  }
  return colors[hash.abs() % colors.length];
}

String _hex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0')}';
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
