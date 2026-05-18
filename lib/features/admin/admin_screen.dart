import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/browser_url.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../models/models.dart';

final adminControllerProvider =
    AsyncNotifierProvider<AdminController, AdminConsoleState>(
      AdminController.new,
    );

enum AdminSection { members, projects, audit }

enum RoleFilter { all, admin, member }

enum SortDirection { ascending, descending }

enum MemberSortKey { name, email, title, role, joined }

enum ProjectSortKey { name, members, code, created }

@immutable
class AdminConsoleState {
  const AdminConsoleState({
    this.members = const <TenantMembership>[],
    this.projects = const <ProjectListItem>[],
    this.currentUserId,
    this.activeTenant,
    this.busyId,
  });

  final List<TenantMembership> members;
  final List<ProjectListItem> projects;
  final String? currentUserId;
  final Tenant? activeTenant;
  final String? busyId;

  TenantMembership? get currentMembership {
    for (final member in members) {
      if (member.userId == currentUserId) {
        return member;
      }
    }
    return null;
  }

  bool get canShowConsole {
    final role = currentMembership?.role;
    return role == 'admin' || role == 'super_admin';
  }

  int get adminCount => members
      .where((member) => member.role == 'admin' || member.role == 'super_admin')
      .length;

  AdminConsoleState copyWith({
    List<TenantMembership>? members,
    List<ProjectListItem>? projects,
    String? currentUserId,
    Tenant? activeTenant,
    String? busyId,
    bool clearBusy = false,
  }) {
    return AdminConsoleState(
      members: members ?? this.members,
      projects: projects ?? this.projects,
      currentUserId: currentUserId ?? this.currentUserId,
      activeTenant: activeTenant ?? this.activeTenant,
      busyId: clearBusy ? null : busyId ?? this.busyId,
    );
  }
}

class AdminController extends AsyncNotifier<AdminConsoleState> {
  @override
  Future<AdminConsoleState> build() async {
    final auth = ref.watch(authControllerProvider).asData?.value;
    final tenant = auth?.activeTenant;
    final user = auth?.user;
    if (tenant == null || user == null) {
      return const AdminConsoleState();
    }

    final results = await Future.wait<Object>([
      ref.watch(userServiceProvider).tenantMembers(),
      ref.watch(projectServiceProvider).list(includeArchived: true),
    ]);

    return AdminConsoleState(
      members: results[0] as List<TenantMembership>,
      projects: results[1] as List<ProjectListItem>,
      currentUserId: user.id,
      activeTenant: tenant,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> toggleAdmin(String userId) async {
    final current = state.requireValue;
    if (userId == current.currentUserId) {
      return;
    }
    final member = current.members
        .where((item) => item.userId == userId)
        .firstOrNull;
    if (member == null) {
      return;
    }

    final newRole = member.role == 'admin' || member.role == 'super_admin'
        ? 'member'
        : 'admin';
    state = AsyncData(current.copyWith(busyId: 'member:$userId'));
    try {
      await ref
          .read(adminServiceProvider)
          .updateTenantMemberRole(
            tenantId: member.tenantId,
            userId: userId,
            role: newRole,
          );
      await _reloadData(clearBusy: true);
    } catch (_) {
      state = AsyncData(current.copyWith(clearBusy: true));
      rethrow;
    }
  }

  Future<void> removeMember(String userId) async {
    final current = state.requireValue;
    if (userId == current.currentUserId) {
      return;
    }
    final member = current.members
        .where((item) => item.userId == userId)
        .firstOrNull;
    if (member == null) {
      return;
    }

    state = AsyncData(current.copyWith(busyId: 'member:$userId'));
    try {
      await ref
          .read(adminServiceProvider)
          .removeTenantMember(tenantId: member.tenantId, userId: userId);
      await _reloadData(clearBusy: true);
    } catch (_) {
      state = AsyncData(current.copyWith(clearBusy: true));
      rethrow;
    }
  }

  Future<void> toggleProjectArchive(String projectId) async {
    final current = state.requireValue;
    final project = current.projects
        .where((item) => item.id == projectId)
        .firstOrNull;
    if (project == null) {
      return;
    }

    state = AsyncData(current.copyWith(busyId: 'project:$projectId'));
    try {
      if (project.isArchived) {
        await ref.read(projectServiceProvider).unarchive(projectId);
      } else {
        await ref.read(projectServiceProvider).archive(projectId);
      }
      await _reloadData(clearBusy: true);
    } catch (_) {
      state = AsyncData(current.copyWith(clearBusy: true));
      rethrow;
    }
  }

  Future<String> workspaceInviteLink() async {
    final current = state.requireValue;
    final tenant = current.activeTenant;
    if (tenant == null) {
      throw const ApiException(null, 'No active workspace selected.');
    }
    final freshTenant = await ref.read(tenantServiceProvider).get(tenant.id);
    final inviteCode = freshTenant?.inviteCode ?? tenant.inviteCode;
    if (inviteCode.isEmpty) {
      throw const ApiException(null, 'Workspace invite code is unavailable.');
    }
    final uri = currentBrowserUri();
    final origin = uri.hasScheme && uri.host.isNotEmpty
        ? '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}'
        : '';
    return '$origin/join-workspace/$inviteCode';
  }

  Future<void> _reloadData({required bool clearBusy}) async {
    final current = state.requireValue;
    final results = await Future.wait<Object>([
      ref.read(userServiceProvider).tenantMembers(),
      ref.read(projectServiceProvider).list(includeArchived: true),
    ]);
    state = AsyncData(
      current.copyWith(
        members: results[0] as List<TenantMembership>,
        projects: results[1] as List<ProjectListItem>,
        clearBusy: clearBusy,
      ),
    );
  }
}

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _memberSearch = TextEditingController();
  final _projectSearch = TextEditingController();
  AdminSection _section = AdminSection.members;
  RoleFilter _roleFilter = RoleFilter.all;
  MemberSortKey _memberSortKey = MemberSortKey.name;
  ProjectSortKey _projectSortKey = ProjectSortKey.created;
  SortDirection _memberSortDirection = SortDirection.ascending;
  SortDirection _projectSortDirection = SortDirection.descending;

  @override
  void dispose() {
    _memberSearch.dispose();
    _projectSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminControllerProvider);
    return Scaffold(
      body: Stack(
        children: [
          const _AdminGlow(),
          SafeArea(
            child: value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _AdminError(
                message: _messageFor(error),
                onRetry: () => ref.invalidate(adminControllerProvider),
              ),
              data: (state) {
                if (state.currentUserId == null || state.activeTenant == null) {
                  return const _AdminGate(
                    title: 'No workspace selected',
                    message:
                        'Choose a workspace before opening the admin console.',
                  );
                }
                if (!state.canShowConsole) {
                  return const _AdminGate(
                    title: 'Admin access required',
                    message:
                        'This console is shown only to tenant admins and super admins. Backend permissions still apply to every action.',
                  );
                }
                return _AdminShell(
                  state: state,
                  section: _section,
                  roleFilter: _roleFilter,
                  memberSearch: _memberSearch,
                  projectSearch: _projectSearch,
                  memberSortKey: _memberSortKey,
                  memberSortDirection: _memberSortDirection,
                  projectSortKey: _projectSortKey,
                  projectSortDirection: _projectSortDirection,
                  onSectionChanged: (section) =>
                      setState(() => _section = section),
                  onRoleFilterChanged: (filter) =>
                      setState(() => _roleFilter = filter),
                  onMemberSort: _sortMembersBy,
                  onProjectSort: _sortProjectsBy,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _sortMembersBy(MemberSortKey key) {
    setState(() {
      if (_memberSortKey == key) {
        _memberSortDirection = _toggle(_memberSortDirection);
      } else {
        _memberSortKey = key;
        _memberSortDirection = SortDirection.ascending;
      }
    });
  }

  void _sortProjectsBy(ProjectSortKey key) {
    setState(() {
      if (_projectSortKey == key) {
        _projectSortDirection = _toggle(_projectSortDirection);
      } else {
        _projectSortKey = key;
        _projectSortDirection = key == ProjectSortKey.created
            ? SortDirection.descending
            : SortDirection.ascending;
      }
    });
  }
}

class _AdminShell extends ConsumerWidget {
  const _AdminShell({
    required this.state,
    required this.section,
    required this.roleFilter,
    required this.memberSearch,
    required this.projectSearch,
    required this.memberSortKey,
    required this.memberSortDirection,
    required this.projectSortKey,
    required this.projectSortDirection,
    required this.onSectionChanged,
    required this.onRoleFilterChanged,
    required this.onMemberSort,
    required this.onProjectSort,
  });

  final AdminConsoleState state;
  final AdminSection section;
  final RoleFilter roleFilter;
  final TextEditingController memberSearch;
  final TextEditingController projectSearch;
  final MemberSortKey memberSortKey;
  final SortDirection memberSortDirection;
  final ProjectSortKey projectSortKey;
  final SortDirection projectSortDirection;
  final ValueChanged<AdminSection> onSectionChanged;
  final ValueChanged<RoleFilter> onRoleFilterChanged;
  final ValueChanged<MemberSortKey> onMemberSort;
  final ValueChanged<ProjectSortKey> onProjectSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = _AdminContent(
      state: state,
      section: section,
      roleFilter: roleFilter,
      memberSearch: memberSearch,
      projectSearch: projectSearch,
      memberSortKey: memberSortKey,
      memberSortDirection: memberSortDirection,
      projectSortKey: projectSortKey,
      projectSortDirection: projectSortDirection,
      onRoleFilterChanged: onRoleFilterChanged,
      onMemberSort: onMemberSort,
      onProjectSort: onProjectSort,
    );

    return Column(
      children: [
        _AdminTopBar(
          section: section,
          onExportCsv: () => _exportMembersCsv(context, state.members),
          onCopyInvite: () => _copyInvite(context, ref),
          onRefresh: () => ref.invalidate(adminControllerProvider),
        ),
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 230,
                      child: _AdminNav(
                        state: state,
                        section: section,
                        onChanged: onSectionChanged,
                      ),
                    ),
                    Expanded(child: content),
                  ],
                )
              : Column(
                  children: [
                    _AdminNav(
                      state: state,
                      section: section,
                      onChanged: onSectionChanged,
                    ),
                    Expanded(child: content),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.section,
    required this.onExportCsv,
    required this.onCopyInvite,
    required this.onRefresh,
  });

  final AdminSection section;
  final VoidCallback onExportCsv;
  final VoidCallback onCopyInvite;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: tokens.background.withValues(alpha: tokens.isDark ? 0.84 : 0.78),
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to profile',
            onPressed: () => context.go('/profile/account'),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 4),
          Text('ADMIN', style: _eyebrowStyle(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: tokens.faint,
            ),
          ),
          Expanded(
            child: Text(
              _sectionLabel(section),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (section == AdminSection.members) ...[
            IconButton(
              tooltip: 'Export members CSV',
              onPressed: onExportCsv,
              icon: const Icon(Icons.download_rounded),
            ),
            IconButton(
              tooltip: 'Copy workspace invite link',
              onPressed: onCopyInvite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
          ],
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdminNav extends StatelessWidget {
  const _AdminNav({
    required this.state,
    required this.section,
    required this.onChanged,
  });

  final AdminConsoleState state;
  final AdminSection section;
  final ValueChanged<AdminSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: wide ? BorderSide(color: tokens.border) : BorderSide.none,
          bottom: !wide ? BorderSide(color: tokens.border) : BorderSide.none,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: wide ? Axis.vertical : Axis.horizontal,
        padding: const EdgeInsets.all(14),
        child: Flex(
          direction: wide ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide) _WorkspaceSummary(state: state),
            _NavButton(
              active: section == AdminSection.members,
              icon: Icons.people_alt_outlined,
              label: 'Members',
              count: state.members.length,
              onTap: () => onChanged(AdminSection.members),
            ),
            _NavButton(
              active: section == AdminSection.projects,
              icon: Icons.folder_copy_outlined,
              label: 'Projects',
              count: state.projects.length,
              onTap: () => onChanged(AdminSection.projects),
            ),
            _NavButton(
              active: section == AdminSection.audit,
              icon: Icons.history_rounded,
              label: 'Audit log',
              onTap: () => onChanged(AdminSection.audit),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSummary extends StatelessWidget {
  const _WorkspaceSummary({required this.state});

  final AdminConsoleState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: tokens.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WORKSPACE', style: _eyebrowStyle(context)),
          const SizedBox(height: 5),
          Text(
            state.activeTenant?.name ?? 'Workspace',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _TinyMetric(label: 'members', value: '${state.members.length}'),
              _TinyMetric(label: 'admins', value: '${state.adminCount}'),
              _TinyMetric(label: 'projects', value: '${state.projects.length}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.clamp(0, 8)),
        child: Container(
          width: wide ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? tokens.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radius.clamp(0, 8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: active ? tokens.accent : tokens.dim),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active ? tokens.accent : tokens.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tokens.faint,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminContent extends StatelessWidget {
  const _AdminContent({
    required this.state,
    required this.section,
    required this.roleFilter,
    required this.memberSearch,
    required this.projectSearch,
    required this.memberSortKey,
    required this.memberSortDirection,
    required this.projectSortKey,
    required this.projectSortDirection,
    required this.onRoleFilterChanged,
    required this.onMemberSort,
    required this.onProjectSort,
  });

  final AdminConsoleState state;
  final AdminSection section;
  final RoleFilter roleFilter;
  final TextEditingController memberSearch;
  final TextEditingController projectSearch;
  final MemberSortKey memberSortKey;
  final SortDirection memberSortDirection;
  final ProjectSortKey projectSortKey;
  final SortDirection projectSortDirection;
  final ValueChanged<RoleFilter> onRoleFilterChanged;
  final ValueChanged<MemberSortKey> onMemberSort;
  final ValueChanged<ProjectSortKey> onProjectSort;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([memberSearch, projectSearch]),
      builder: (context, _) {
        final members = _filteredMembers(
          state.members,
          memberSearch.text,
          roleFilter,
          memberSortKey,
          memberSortDirection,
        );
        final projects = _filteredProjects(
          state.projects,
          projectSearch.text,
          projectSortKey,
          projectSortDirection,
        );

        return switch (section) {
          AdminSection.projects => _ProjectsPanel(
            projects: projects,
            totalCount: state.projects.length,
            search: projectSearch,
            sortKey: projectSortKey,
            sortDirection: projectSortDirection,
            busyId: state.busyId,
            onSort: onProjectSort,
          ),
          AdminSection.audit => const _AuditPanel(),
          AdminSection.members => _MembersPanel(
            members: members,
            totalCount: state.members.length,
            currentUserId: state.currentUserId!,
            search: memberSearch,
            roleFilter: roleFilter,
            sortKey: memberSortKey,
            sortDirection: memberSortDirection,
            busyId: state.busyId,
            onRoleFilterChanged: onRoleFilterChanged,
            onSort: onMemberSort,
          ),
        };
      },
    );
  }
}

class _MembersPanel extends ConsumerWidget {
  const _MembersPanel({
    required this.members,
    required this.totalCount,
    required this.currentUserId,
    required this.search,
    required this.roleFilter,
    required this.sortKey,
    required this.sortDirection,
    required this.busyId,
    required this.onRoleFilterChanged,
    required this.onSort,
  });

  final List<TenantMembership> members;
  final int totalCount;
  final String currentUserId;
  final TextEditingController search;
  final RoleFilter roleFilter;
  final MemberSortKey sortKey;
  final SortDirection sortDirection;
  final String? busyId;
  final ValueChanged<RoleFilter> onRoleFilterChanged;
  final ValueChanged<MemberSortKey> onSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 780;
    return _PanelScroll(
      title: 'Members',
      subtitle: '${members.length} of $totalCount shown',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: wide ? 260 : double.infinity,
            child: TextField(
              controller: search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search members',
              ),
            ),
          ),
          DropdownButton<RoleFilter>(
            value: roleFilter,
            onChanged: (value) {
              if (value != null) {
                onRoleFilterChanged(value);
              }
            },
            items: const [
              DropdownMenuItem(value: RoleFilter.all, child: Text('All roles')),
              DropdownMenuItem(value: RoleFilter.admin, child: Text('Admins')),
              DropdownMenuItem(
                value: RoleFilter.member,
                child: Text('Members'),
              ),
            ],
          ),
        ],
      ),
      child: wide
          ? _MembersTable(
              members: members,
              currentUserId: currentUserId,
              sortKey: sortKey,
              sortDirection: sortDirection,
              busyId: busyId,
              onSort: onSort,
            )
          : Column(
              children: [
                for (final member in members)
                  _MemberCard(
                    member: member,
                    currentUserId: currentUserId,
                    busy: busyId == 'member:${member.userId}',
                  ),
              ],
            ),
    );
  }
}

class _MembersTable extends StatelessWidget {
  const _MembersTable({
    required this.members,
    required this.currentUserId,
    required this.sortKey,
    required this.sortDirection,
    required this.busyId,
    required this.onSort,
  });

  final List<TenantMembership> members;
  final String currentUserId;
  final MemberSortKey sortKey;
  final SortDirection sortDirection;
  final String? busyId;
  final ValueChanged<MemberSortKey> onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return _TableFrame(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: _eyebrowStyle(context),
          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
          columns: [
            _memberColumn('Name', MemberSortKey.name),
            _memberColumn('Email', MemberSortKey.email),
            _memberColumn('Title', MemberSortKey.title),
            _memberColumn('Role', MemberSortKey.role),
            _memberColumn('Joined', MemberSortKey.joined),
            const DataColumn(label: SizedBox.shrink()),
          ],
          rows: [
            for (final member in members)
              DataRow(
                cells: [
                  DataCell(_MemberIdentity(member.user)),
                  DataCell(Text(member.user.email)),
                  DataCell(
                    Text(member.user.title.isEmpty ? '-' : member.user.title),
                  ),
                  DataCell(_RoleBadge(role: member.role)),
                  DataCell(Text(_formatRelativeDate(member.createdAt))),
                  DataCell(
                    busyId == 'member:${member.userId}'
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tokens.accent,
                            ),
                          )
                        : _MemberActions(
                            member: member,
                            currentUserId: currentUserId,
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  DataColumn _memberColumn(String label, MemberSortKey key) {
    return DataColumn(
      label: _SortLabel(
        label: label,
        active: sortKey == key,
        direction: sortDirection,
      ),
      onSort: (_, _) => onSort(key),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.currentUserId,
    required this.busy,
  });

  final TenantMembership member;
  final String currentUserId;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: tokens.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MemberIdentity(member.user)),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _MemberActions(member: member, currentUserId: currentUserId),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RoleBadge(role: member.role),
              Text(
                member.user.email,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.dim),
              ),
              Text(
                'Joined ${_formatRelativeDate(member.createdAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.faint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberActions extends ConsumerWidget {
  const _MemberActions({required this.member, required this.currentUserId});

  final TenantMembership member;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelf = member.userId == currentUserId;
    final isAdmin = member.role == 'admin' || member.role == 'super_admin';
    return PopupMenuButton<String>(
      tooltip: 'Member actions',
      enabled: !isSelf,
      onSelected: (value) async {
        if (value == 'role') {
          await _runAction(
            context,
            () => ref
                .read(adminControllerProvider.notifier)
                .toggleAdmin(member.userId),
          );
        } else if (value == 'remove') {
          final confirmed = await _confirmRemove(context, member.user.name);
          if (confirmed && context.mounted) {
            await _runAction(
              context,
              () => ref
                  .read(adminControllerProvider.notifier)
                  .removeMember(member.userId),
            );
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'role',
          child: Text(isAdmin ? 'Demote to member' : 'Promote to admin'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'remove',
          child: Text('Remove from workspace'),
        ),
      ],
      child: Icon(
        Icons.more_horiz_rounded,
        color: isSelf ? context.maia.faint : context.maia.dim,
      ),
    );
  }
}

class _ProjectsPanel extends ConsumerWidget {
  const _ProjectsPanel({
    required this.projects,
    required this.totalCount,
    required this.search,
    required this.sortKey,
    required this.sortDirection,
    required this.busyId,
    required this.onSort,
  });

  final List<ProjectListItem> projects;
  final int totalCount;
  final TextEditingController search;
  final ProjectSortKey sortKey;
  final SortDirection sortDirection;
  final String? busyId;
  final ValueChanged<ProjectSortKey> onSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 780;
    return _PanelScroll(
      title: 'Projects',
      subtitle: '${projects.length} of $totalCount shown',
      trailing: SizedBox(
        width: wide ? 280 : double.infinity,
        child: TextField(
          controller: search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search projects',
          ),
        ),
      ),
      child: wide
          ? _ProjectsTable(
              projects: projects,
              sortKey: sortKey,
              sortDirection: sortDirection,
              busyId: busyId,
              onSort: onSort,
            )
          : Column(
              children: [
                for (final project in projects)
                  _ProjectCard(
                    project: project,
                    busy: busyId == 'project:${project.id}',
                  ),
              ],
            ),
    );
  }
}

class _ProjectsTable extends StatelessWidget {
  const _ProjectsTable({
    required this.projects,
    required this.sortKey,
    required this.sortDirection,
    required this.busyId,
    required this.onSort,
  });

  final List<ProjectListItem> projects;
  final ProjectSortKey sortKey;
  final SortDirection sortDirection;
  final String? busyId;
  final ValueChanged<ProjectSortKey> onSort;

  @override
  Widget build(BuildContext context) {
    return _TableFrame(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: _eyebrowStyle(context),
          columns: [
            _projectColumn('Project', ProjectSortKey.name),
            _projectColumn('Members', ProjectSortKey.members, numeric: true),
            _projectColumn('Code', ProjectSortKey.code),
            _projectColumn('Created', ProjectSortKey.created),
            const DataColumn(label: SizedBox.shrink()),
          ],
          rows: [
            for (final project in projects)
              DataRow(
                color: WidgetStatePropertyAll(
                  project.isArchived
                      ? context.maia.faint.withValues(alpha: 0.04)
                      : Colors.transparent,
                ),
                cells: [
                  DataCell(_ProjectIdentity(project: project)),
                  DataCell(Text('${project.memberCount}')),
                  DataCell(Text(project.code)),
                  DataCell(Text(_formatRelativeDate(project.createdAt))),
                  DataCell(
                    _ProjectArchiveButton(
                      project: project,
                      busy: busyId == 'project:${project.id}',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  DataColumn _projectColumn(
    String label,
    ProjectSortKey key, {
    bool numeric = false,
  }) {
    return DataColumn(
      numeric: numeric,
      label: _SortLabel(
        label: label,
        active: sortKey == key,
        direction: sortDirection,
      ),
      onSort: (_, _) => onSort(key),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.busy});

  final ProjectListItem project;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: tokens.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _ProjectIdentity(project: project)),
              _ProjectArchiveButton(project: project, busy: busy),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _TinyMetric(label: 'members', value: '${project.memberCount}'),
              _TinyMetric(label: 'code', value: project.code),
              _TinyMetric(
                label: 'created',
                value: _formatRelativeDate(project.createdAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectArchiveButton extends ConsumerWidget {
  const _ProjectArchiveButton({required this.project, required this.busy});

  final ProjectListItem project;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (busy) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _runAction(
        context,
        () => ref
            .read(adminControllerProvider.notifier)
            .toggleProjectArchive(project.id),
      ),
      icon: Icon(
        project.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
      ),
      label: Text(project.isArchived ? 'Unarchive' : 'Archive'),
    );
  }
}

class _AuditPanel extends StatelessWidget {
  const _AuditPanel();

  @override
  Widget build(BuildContext context) {
    return const _PanelScroll(
      title: 'Audit log',
      subtitle: 'Administrative activity across the workspace.',
      child: _ComingSoonCard(
        icon: Icons.history_edu_rounded,
        title: 'Coming soon',
        message:
            'Role changes, member removals, project archival, invite activity, and workspace settings changes will appear here when the backend audit feed is available.',
      ),
    );
  }
}

class _PanelScroll extends StatelessWidget {
  const _PanelScroll({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 780;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _PanelHeader(title: title, subtitle: subtitle),
                        ),
                        ?trailing,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PanelHeader(title: title, subtitle: subtitle),
                        if (trailing != null) ...[
                          const SizedBox(height: 14),
                          trailing!,
                        ],
                      ],
                    ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.maia.dim),
        ),
      ],
    );
  }
}

class _TableFrame extends StatelessWidget {
  const _TableFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: context.maia.surfaceDecoration(),
      child: child,
    );
  }
}

class _MemberIdentity extends StatelessWidget {
  const _MemberIdentity(this.user);

  final User user;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(user: user),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (user.title.isNotEmpty)
                Text(
                  user.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.maia.faint),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectIdentity extends StatelessWidget {
  const _ProjectIdentity({required this.project});

  final ProjectListItem project;

  @override
  Widget build(BuildContext context) {
    final accent = _colorFromHex(project.accentColor) ?? context.maia.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            project.code,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (project.isArchived) const _ArchiveBadge(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

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
    return CircleAvatar(
      radius: 18,
      foregroundImage: user.avatarUrl == null
          ? null
          : NetworkImage(user.avatarUrl!),
      backgroundColor: context.maia.accentSoft,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.maia.accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final admin = role == 'admin' || role == 'super_admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: admin ? tokens.accentSoft : tokens.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: admin ? tokens.accentSoft : tokens.border),
      ),
      child: Text(
        _roleLabel(role),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: admin ? tokens.accent : tokens.dim,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ArchiveBadge extends StatelessWidget {
  const _ArchiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.maia.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.maia.border),
      ),
      child: Text('Archived', style: _eyebrowStyle(context)),
    );
  }
}

class _SortLabel extends StatelessWidget {
  const _SortLabel({
    required this.label,
    required this.active,
    required this.direction,
  });

  final String label;
  final bool active;
  final SortDirection direction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 4),
        Icon(
          !active
              ? Icons.unfold_more_rounded
              : direction == SortDirection.ascending
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: active ? context.maia.accent : context.maia.faint,
        ),
      ],
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.maia.faint,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(color: context.maia.text),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: tokens.surfaceDecoration(),
      child: Row(
        children: [
          Icon(icon, color: tokens.faint),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.dim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminGate extends StatelessWidget {
  const _AdminGate({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _ComingSoonCard(
            icon: Icons.admin_panel_settings_outlined,
            title: title,
            message: message,
          ),
        ),
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: context.maia.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AdminGlow extends StatelessWidget {
  const _AdminGlow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.78),
            radius: 1.05,
            colors: [
              tokens.accent.withValues(alpha: tokens.isDark ? 0.07 : 0.10),
              tokens.background,
            ],
            stops: const [0, 0.72],
          ),
        ),
      ),
    );
  }
}

List<TenantMembership> _filteredMembers(
  List<TenantMembership> members,
  String query,
  RoleFilter roleFilter,
  MemberSortKey sortKey,
  SortDirection direction,
) {
  final q = query.trim().toLowerCase();
  final filtered = members.where((member) {
    final admin = member.role == 'admin' || member.role == 'super_admin';
    if (roleFilter == RoleFilter.admin && !admin) {
      return false;
    }
    if (roleFilter == RoleFilter.member && admin) {
      return false;
    }
    if (q.isEmpty) {
      return true;
    }
    return member.user.name.toLowerCase().contains(q) ||
        member.user.email.toLowerCase().contains(q) ||
        member.user.title.toLowerCase().contains(q);
  }).toList();

  filtered.sort((a, b) {
    final result = switch (sortKey) {
      MemberSortKey.name => a.user.name.toLowerCase().compareTo(
        b.user.name.toLowerCase(),
      ),
      MemberSortKey.email => a.user.email.toLowerCase().compareTo(
        b.user.email.toLowerCase(),
      ),
      MemberSortKey.title => a.user.title.toLowerCase().compareTo(
        b.user.title.toLowerCase(),
      ),
      MemberSortKey.role => a.role.compareTo(b.role),
      MemberSortKey.joined => a.createdAt.compareTo(b.createdAt),
    };
    return direction == SortDirection.ascending ? result : -result;
  });
  return filtered;
}

List<ProjectListItem> _filteredProjects(
  List<ProjectListItem> projects,
  String query,
  ProjectSortKey sortKey,
  SortDirection direction,
) {
  final q = query.trim().toLowerCase();
  final filtered = projects.where((project) {
    if (q.isEmpty) {
      return true;
    }
    return project.name.toLowerCase().contains(q) ||
        project.code.toLowerCase().contains(q);
  }).toList();

  filtered.sort((a, b) {
    final result = switch (sortKey) {
      ProjectSortKey.name => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      ProjectSortKey.members => a.memberCount.compareTo(b.memberCount),
      ProjectSortKey.code => a.code.compareTo(b.code),
      ProjectSortKey.created => a.createdAt.compareTo(b.createdAt),
    };
    return direction == SortDirection.ascending ? result : -result;
  });
  return filtered;
}

Future<void> _copyInvite(BuildContext context, WidgetRef ref) async {
  try {
    final link = await ref
        .read(adminControllerProvider.notifier)
        .workspaceInviteLink();
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      _showSnack(context, 'Workspace invite link copied.');
    }
  } catch (error) {
    if (context.mounted) {
      _showSnack(context, _messageFor(error));
    }
  }
}

Future<void> _exportMembersCsv(
  BuildContext context,
  List<TenantMembership> members,
) async {
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final rows = <List<String>>[
    const ['Name', 'Email', 'Title', 'Role', 'Joined'],
    for (final member in members)
      [
        member.user.name,
        member.user.email,
        member.user.title,
        member.role,
        DateFormat('yyyy-MM-dd').format(member.createdAt),
      ],
  ];
  final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  final uri = Uri.dataFromString(csv, mimeType: 'text/csv', encoding: utf8);
  final opened = await launchUrl(
    uri,
    webOnlyWindowName: 'maia-members-$date.csv',
  );
  if (!opened) {
    await Clipboard.setData(ClipboardData(text: csv));
  }
  if (context.mounted) {
    _showSnack(
      context,
      opened ? 'CSV export opened in a new tab.' : 'CSV copied to clipboard.',
    );
  }
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      _showSnack(context, _messageFor(error));
    }
  }
}

Future<bool> _confirmRemove(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          'Remove $name from this workspace? They will lose access to workspace projects.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

SortDirection _toggle(SortDirection direction) {
  return direction == SortDirection.ascending
      ? SortDirection.descending
      : SortDirection.ascending;
}

String _sectionLabel(AdminSection section) {
  return switch (section) {
    AdminSection.members => 'Members',
    AdminSection.projects => 'Projects',
    AdminSection.audit => 'Audit log',
  };
}

String _roleLabel(String role) {
  return switch (role) {
    'super_admin' => 'Super admin',
    'admin' => 'Admin',
    _ => 'Member',
  };
}

String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inHours < 24) {
    return 'today';
  }
  if (diff.inDays < 2) {
    return 'yesterday';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays}d ago';
  }
  if (diff.inDays < 365) {
    return '${(diff.inDays / 30).floor()}mo ago';
  }
  return DateFormat.yMMMd().format(date);
}

String _csvCell(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

String _messageFor(Object error) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Request failed. Please try again.';
}

Color? _colorFromHex(String value) {
  final hex = value.trim().replaceFirst('#', '');
  if (hex.length != 6) {
    return null;
  }
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(0xFF000000 | parsed);
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

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
