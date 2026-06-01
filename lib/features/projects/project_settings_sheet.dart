import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../models/models.dart';
import 'connectors_panel.dart';
import 'project_avatar_widget.dart';
import 'project_icon_registry.dart';

const _digestDelayPresets = <int>[
  15,
  20,
  30,
  45,
  60,
  90,
  120,
  150,
  180,
  240,
  300,
  360,
];

const _commonTimezones = <String>[
  'UTC',
  'US/Eastern',
  'US/Central',
  'US/Mountain',
  'US/Pacific',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Asia/Kolkata',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Australia/Sydney',
  'Pacific/Auckland',
];

enum _SettingsTab { general, schedule, members, connectors, invite }

class ProjectSettingsSheet extends ConsumerStatefulWidget {
  const ProjectSettingsSheet({
    required this.project,
    required this.isCurrentUserAdmin,
    required this.canDeleteProject,
    required this.onUpdated,
    required this.onDeleted,
    super.key,
  });

  final ProjectWithMembers project;
  final bool isCurrentUserAdmin;
  final bool canDeleteProject;
  final FutureOr<void> Function() onUpdated;
  final VoidCallback onDeleted;

  @override
  ConsumerState<ProjectSettingsSheet> createState() =>
      _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends ConsumerState<ProjectSettingsSheet> {
  final _nameController = TextEditingController();
  List<TenantMembership> _tenantMembers = const <TenantMembership>[];
  _SettingsTab _tab = _SettingsTab.general;
  String? _icon;
  String _checkinTime = '09:00';
  String _timezone = 'UTC';
  int _digestDelay = 60;
  bool _saving = false;
  bool _loadingMembers = true;
  String? _memberAction;
  String? _error;
  bool _saved = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _syncFromProject();
    unawaited(_loadTenantMembers());
  }

  @override
  void didUpdateWidget(covariant ProjectSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id ||
        oldWidget.project.updatedAt != widget.project.updatedAt) {
      _syncFromProject();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncFromProject() {
    _nameController.text = widget.project.name;
    _icon = widget.project.icon;
    _checkinTime = _timeForInput(widget.project.checkinTime);
    _timezone = _commonTimezones.contains(widget.project.checkinTimezone)
        ? widget.project.checkinTimezone
        : 'UTC';
    _digestDelay =
        _digestDelayPresets.contains(widget.project.digestDelayMinutes)
        ? widget.project.digestDelayMinutes
        : 60;
  }

  Future<void> _loadTenantMembers() async {
    try {
      final members = await ref.read(userServiceProvider).tenantMembers();
      if (mounted) {
        setState(() {
          _tenantMembers = members;
          _loadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  bool get _dirty {
    return _nameController.text.trim() != widget.project.name ||
        _icon != widget.project.icon ||
        _checkinTime != _timeForInput(widget.project.checkinTime) ||
        _timezone != widget.project.checkinTimezone ||
        _digestDelay != widget.project.digestDelayMinutes;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final validation = _validateSettings(
      name,
      _checkinTime,
      _timezone,
      _digestDelay,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      await ref
          .read(projectServiceProvider)
          .update(
            widget.project.id,
            name: name,
            icon: _icon,
            checkinTime: _checkinTime,
            checkinTimezone: _timezone,
            digestDelayMinutes: _digestDelay,
          );
      await widget.onUpdated();
      if (mounted) {
        setState(() => _saved = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addMember(String userId) async {
    await _memberMutation(
      userId,
      () =>
          ref.read(projectServiceProvider).addMember(widget.project.id, userId),
    );
  }

  Future<void> _removeMember(String userId) async {
    await _memberMutation(
      userId,
      () => ref
          .read(projectServiceProvider)
          .removeMember(widget.project.id, userId),
    );
  }

  Future<void> _setMemberRole(String userId, String role) async {
    await _memberMutation(
      userId,
      () => ref
          .read(projectServiceProvider)
          .updateMember(widget.project.id, userId, role: role),
    );
  }

  Future<void> _toggleCheckin(ProjectMember member) async {
    await _memberMutation(
      member.userId,
      () => ref
          .read(projectServiceProvider)
          .updateMember(
            widget.project.id,
            member.userId,
            checkinEnabled: !member.checkinEnabled,
          ),
    );
  }

  Future<void> _memberMutation(
    String userId,
    FutureOr<Object?> Function() fn,
  ) async {
    setState(() {
      _memberAction = userId;
      _error = null;
    });
    try {
      await fn();
      await widget.onUpdated();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _memberAction = null);
      }
    }
  }

  Future<void> _copyInvite() async {
    await Clipboard.setData(ClipboardData(text: widget.project.inviteCode));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite code copied.')));
  }

  Future<void> _deleteProject() async {
    setState(() {
      _deleting = true;
      _error = null;
      _saved = false;
    });
    try {
      await ref.read(projectServiceProvider).deleteProject(widget.project.id);
      if (mounted) {
        widget.onDeleted();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _deleteMessageFor(error);
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 760;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: desktop ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: desktop ? 900 : double.infinity,
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: Material(
            color: tokens.backgroundRaised,
            elevation: 18,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.radius + 10),
              bottom: desktop
                  ? Radius.circular(tokens.radius + 10)
                  : Radius.zero,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _Header(
                  project: widget.project,
                  icon: _icon,
                  onClose: () => Navigator.pop(context),
                ),
                Expanded(
                  child: desktop
                      ? Row(
                          children: [
                            _TabRail(value: _tab, onChanged: _setTab),
                            VerticalDivider(width: 1, color: tokens.border),
                            Expanded(child: _panel()),
                          ],
                        )
                      : Column(
                          children: [
                            _TabStrip(value: _tab, onChanged: _setTab),
                            Divider(height: 1, color: tokens.border),
                            Expanded(child: _panel()),
                          ],
                        ),
                ),
                _SaveBar(
                  visible: _dirty || _saved || _error != null,
                  saving: _saving,
                  saved: _saved,
                  error: _error,
                  canSave: _nameController.text.trim().isNotEmpty,
                  onDiscard: () {
                    setState(() {
                      _syncFromProject();
                      _error = null;
                      _saved = false;
                    });
                  },
                  onSave: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setTab(_SettingsTab tab) {
    setState(() {
      _tab = tab;
      _error = null;
      _saved = false;
    });
  }

  Widget _panel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 120),
      child: switch (_tab) {
        _SettingsTab.general => _GeneralPanel(
          project: widget.project,
          nameController: _nameController,
          icon: _icon,
          canDelete: widget.canDeleteProject,
          deleting: _deleting,
          onIconChanged: (value) => setState(() => _icon = value),
          onChanged: () => setState(() {
            _saved = false;
            _error = null;
          }),
          onDelete: _deleteProject,
        ),
        _SettingsTab.schedule => _SchedulePanel(
          checkinTime: _checkinTime,
          timezone: _timezone,
          digestDelay: _digestDelay,
          onTimeChanged: (value) => setState(() => _checkinTime = value),
          onTimezoneChanged: (value) => setState(() => _timezone = value),
          onDigestChanged: (value) => setState(() => _digestDelay = value),
        ),
        _SettingsTab.members => _MembersPanel(
          project: widget.project,
          tenantMembers: _tenantMembers,
          loadingTenantMembers: _loadingMembers,
          actingUserId: _memberAction,
          onAdd: _addMember,
          onRemove: _removeMember,
          onRoleChanged: _setMemberRole,
          onToggleCheckin: _toggleCheckin,
        ),
        _SettingsTab.connectors => _PanelScaffold(
          title: 'Connectors',
          subtitle: 'Google Sheets Maia can read for this project.',
          child: ConnectorsPanel(
            projectId: widget.project.id,
            isAdmin: widget.isCurrentUserAdmin,
          ),
        ),
        _SettingsTab.invite => _InvitePanel(
          project: widget.project,
          onCopy: _copyInvite,
        ),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.project,
    required this.icon,
    required this.onClose,
  });

  final ProjectWithMembers project;
  final String? icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          ProjectAvatarWidget(
            code: project.code,
            icon: icon,
            accent: project.accentColor,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.dim),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _GeneralPanel extends StatelessWidget {
  const _GeneralPanel({
    required this.project,
    required this.nameController,
    required this.icon,
    required this.canDelete,
    required this.deleting,
    required this.onIconChanged,
    required this.onChanged,
    required this.onDelete,
  });

  final ProjectWithMembers project;
  final TextEditingController nameController;
  final String? icon;
  final bool canDelete;
  final bool deleting;
  final ValueChanged<String?> onIconChanged;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'General',
      subtitle: 'Name and icon for the project.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'Customer launch',
            ),
          ),
          const SizedBox(height: 18),
          _IconPicker(
            project: project,
            selected: icon,
            onChanged: onIconChanged,
          ),
          if (canDelete) ...[
            const SizedBox(height: 24),
            _DangerZone(deleting: deleting, onDelete: onDelete),
          ],
        ],
      ),
    );
  }
}

class _DangerZone extends StatefulWidget {
  const _DangerZone({required this.deleting, required this.onDelete});

  final bool deleting;
  final VoidCallback onDelete;

  @override
  State<_DangerZone> createState() => _DangerZoneState();
}

class _DangerZoneState extends State<_DangerZone> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: tokens.isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Danger zone',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Delete this project. It disappears for everyone, and check-ins and digests stop. Threads and history are retained server-side.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.dim),
          ),
          const SizedBox(height: 12),
          if (!_confirming)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.deleting
                    ? null
                    : () => setState(() => _confirming = true),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete project'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.danger,
                  side: BorderSide(color: tokens.danger.withValues(alpha: 0.6)),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: widget.deleting ? null : widget.onDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(widget.deleting ? 'Deleting...' : 'Yes, delete'),
                ),
                TextButton(
                  onPressed: widget.deleting
                      ? null
                      : () => setState(() => _confirming = false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
    required this.checkinTime,
    required this.timezone,
    required this.digestDelay,
    required this.onTimeChanged,
    required this.onTimezoneChanged,
    required this.onDigestChanged,
  });

  final String checkinTime;
  final String timezone;
  final int digestDelay;
  final ValueChanged<String> onTimeChanged;
  final ValueChanged<String> onTimezoneChanged;
  final ValueChanged<int> onDigestChanged;

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Schedule',
      subtitle: 'Daily check-in timing and digest delay.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: checkinTime,
            onChanged: onTimeChanged,
            decoration: const InputDecoration(
              labelText: 'Check-in time',
              hintText: '09:00',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: timezone,
            decoration: const InputDecoration(labelText: 'Timezone'),
            items: [
              for (final tz in _commonTimezones)
                DropdownMenuItem(value: tz, child: Text(tz)),
            ],
            onChanged: (value) {
              if (value != null) {
                onTimezoneChanged(value);
              }
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Digest delay',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _digestDelayPresets)
                ChoiceChip(
                  label: Text(_formatDelay(preset)),
                  selected: digestDelay == preset,
                  onSelected: (_) => onDigestChanged(preset),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Digest lands at ${_computeDigestTime(checkinTime, digestDelay)}.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.maia.dim),
          ),
        ],
      ),
    );
  }
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({
    required this.project,
    required this.tenantMembers,
    required this.loadingTenantMembers,
    required this.actingUserId,
    required this.onAdd,
    required this.onRemove,
    required this.onRoleChanged,
    required this.onToggleCheckin,
  });

  final ProjectWithMembers project;
  final List<TenantMembership> tenantMembers;
  final bool loadingTenantMembers;
  final String? actingUserId;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final void Function(String userId, String role) onRoleChanged;
  final ValueChanged<ProjectMember> onToggleCheckin;

  @override
  Widget build(BuildContext context) {
    final projectMemberIds = project.members.map((m) => m.userId).toSet();
    final available = tenantMembers
        .where((member) => !projectMemberIds.contains(member.userId))
        .toList(growable: false);
    final sorted = [...project.members]
      ..sort((a, b) {
        if (a.role == b.role) {
          return _memberName(a).compareTo(_memberName(b));
        }
        return a.role == 'admin' ? -1 : 1;
      });

    return _PanelScaffold(
      title: 'Members',
      subtitle: 'Manage project roles and daily check-ins.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final member in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MemberRow(
                member: member,
                busy: actingUserId == member.userId,
                onRemove: () => onRemove(member.userId),
                onToggleCheckin: () => onToggleCheckin(member),
                onRoleChanged: (role) => onRoleChanged(member.userId, role),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Available',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (loadingTenantMembers)
            const LinearProgressIndicator(minHeight: 2)
          else if (available.isEmpty)
            Text(
              'Everyone in the workspace is already on this project.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.maia.faint),
            )
          else
            for (final member in available)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: _InitialAvatar(user: member.user),
                title: Text(member.user.name),
                subtitle: Text(
                  member.user.title.isEmpty ? member.role : member.user.title,
                ),
                trailing: TextButton(
                  onPressed: actingUserId == member.userId
                      ? null
                      : () => onAdd(member.userId),
                  child: const Text('Add'),
                ),
              ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.busy,
    required this.onRemove,
    required this.onToggleCheckin,
    required this.onRoleChanged,
  });

  final ProjectMember member;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback onToggleCheckin;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final user = member.user;
    final isAdmin = member.role.toLowerCase() == 'admin';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          _InitialAvatar(user: user),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _memberName(member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  user?.title.isNotEmpty == true
                      ? user!.title
                      : (isAdmin ? 'Project admin' : 'Member'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.dim, fontSize: 12),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: isAdmin ? 'admin' : 'member',
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'member', child: Text('Member')),
            ],
            onChanged: busy
                ? null
                : (role) {
                    if (role != null && role != member.role) {
                      onRoleChanged(role);
                    }
                  },
          ),
          Switch(
            value: member.checkinEnabled,
            onChanged: busy ? null : (_) => onToggleCheckin(),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: busy || isAdmin ? null : onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _InvitePanel extends StatelessWidget {
  const _InvitePanel({required this.project, required this.onCopy});

  final ProjectWithMembers project;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return _PanelScaffold(
      title: 'Invite',
      subtitle: 'Share this code with workspace members.',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tokens.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              project.inviteCode.isEmpty ? '------' : project.inviteCode,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: project.inviteCode.isEmpty ? null : onCopy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy invite code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.project,
    required this.selected,
    required this.onChanged,
  });

  final ProjectWithMembers project;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Icon',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Code'),
              selected: selected == null || selected!.isEmpty,
              onSelected: (_) => onChanged(null),
            ),
            for (final key in ProjectIconRegistry.keys.take(42))
              Tooltip(
                message: key,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(key),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected == key
                          ? tokens.accent.withValues(alpha: 0.16)
                          : tokens.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected == key ? tokens.accent : tokens.border,
                      ),
                    ),
                    child: Icon(
                      ProjectIconRegistry.resolve(key),
                      size: 19,
                      color: selected == key ? tokens.accent : tokens.dim,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name.trim() ?? 'Member';
    return CircleAvatar(
      radius: 17,
      foregroundImage: user?.avatarUrl == null
          ? null
          : NetworkImage(user!.avatarUrl!),
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
    );
  }
}

class _PanelScaffold extends StatelessWidget {
  const _PanelScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: tokens.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.dim),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _TabRail extends StatelessWidget {
  const _TabRail({required this.value, required this.onChanged});

  final _SettingsTab value;
  final ValueChanged<_SettingsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          for (final tab in _SettingsTab.values)
            _TabButton(
              tab: tab,
              selected: value == tab,
              onTap: () => onChanged(tab),
            ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.value, required this.onChanged});

  final _SettingsTab value;
  final ValueChanged<_SettingsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        children: [
          for (final tab in _SettingsTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabButton(
                tab: tab,
                selected: value == tab,
                onTap: () => onChanged(tab),
                compact: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final _SettingsTab tab;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Padding(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? tokens.background : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 10,
              vertical: compact ? 8 : 10,
            ),
            child: Row(
              children: [
                Icon(
                  _tabIcon(tab),
                  size: 18,
                  color: selected ? tokens.accent : tokens.dim,
                ),
                const SizedBox(width: 8),
                Text(
                  _tabLabel(tab),
                  style: TextStyle(
                    color: selected ? tokens.text : tokens.dim,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.visible,
    required this.saving,
    required this.saved,
    required this.error,
    required this.canSave,
    required this.onDiscard,
    required this.onSave,
  });

  final bool visible;
  final bool saving;
  final bool saved;
  final String? error;
  final bool canSave;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: tokens.backgroundRaised,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              error ?? (saved ? 'Saved' : 'Unsaved changes'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: error == null ? tokens.dim : tokens.danger,
              ),
            ),
          ),
          TextButton(
            onPressed: saving ? null : onDiscard,
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: saving || !canSave ? null : onSave,
            child: Text(saving ? 'Saving' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}

IconData _tabIcon(_SettingsTab tab) {
  return switch (tab) {
    _SettingsTab.general => Icons.tune_rounded,
    _SettingsTab.schedule => Icons.schedule_rounded,
    _SettingsTab.members => Icons.group_outlined,
    _SettingsTab.connectors => Icons.link_rounded,
    _SettingsTab.invite => Icons.ios_share_rounded,
  };
}

String _tabLabel(_SettingsTab tab) {
  return switch (tab) {
    _SettingsTab.general => 'General',
    _SettingsTab.schedule => 'Schedule',
    _SettingsTab.members => 'Members',
    _SettingsTab.connectors => 'Connectors',
    _SettingsTab.invite => 'Invite',
  };
}

String? _validateSettings(
  String name,
  String checkinTime,
  String timezone,
  int delay,
) {
  if (name.trim().isEmpty) {
    return 'Project name is required.';
  }
  if (!_isBackendCompatibleTime(checkinTime)) {
    return 'Check-in time must be HH:MM or HH:MM:SS.';
  }
  if (!_commonTimezones.contains(timezone)) {
    return 'Choose a timezone from the list.';
  }
  if (!_digestDelayPresets.contains(delay) || delay < 15) {
    return 'Choose a digest delay of at least 15 minutes.';
  }
  return null;
}

bool _isBackendCompatibleTime(String value) {
  final match = RegExp(
    r'^([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$',
  ).firstMatch(value);
  return match != null;
}

String _timeForInput(String value) {
  final parts = value.split(':');
  if (parts.length >= 2) {
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
  return value;
}

String _formatDelay(int mins) {
  if (mins < 60) {
    return '$mins min';
  }
  if (mins % 60 == 0) {
    return '${mins ~/ 60} hr';
  }
  return '${(mins / 60).toStringAsFixed(1)} hr';
}

String _computeDigestTime(String checkinTime, int delayMinutes) {
  final parts = checkinTime.split(':');
  if (parts.length < 2) {
    return '--:--';
  }
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) {
    return '--:--';
  }
  final total = (hours * 60 + minutes + delayMinutes) % (24 * 60);
  final hh = (total ~/ 60).toString().padLeft(2, '0');
  final mm = (total % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _memberName(ProjectMember member) {
  return member.user?.name.trim().isNotEmpty == true
      ? member.user!.name
      : 'Member';
}

String _messageFor(Object error) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Request failed.';
}

String _deleteMessageFor(Object error) {
  if (error is ApiException && error.status == 403) {
    return 'You need to be the project admin or a workspace admin to delete this project.';
  }
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Failed to delete project';
}
