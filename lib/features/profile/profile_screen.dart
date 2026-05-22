import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../core/theme/maia_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/models.dart';

const _profileSections = <String>{
  'account',
  'appearance',
  'notifications',
  'danger',
};

final _tenantMembersProvider =
    FutureProvider.autoDispose<List<TenantMembership>>((ref) async {
      final auth = ref.watch(authControllerProvider).asData?.value;
      if (auth?.activeTenant == null) {
        return const <TenantMembership>[];
      }
      return ref.watch(userServiceProvider).tenantMembers();
    });

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.section, super.key});

  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = _profileSections.contains(section)
        ? section
        : 'account';
    final authValue = ref.watch(authControllerProvider);
    final auth = authValue.asData?.value;
    final user = auth?.user;

    if (authValue.isLoading || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final membersValue = ref.watch(_tenantMembersProvider);
    final workspaceRole = membersValue.maybeWhen(
      data: (members) {
        for (final member in members) {
          if (member.userId == user.id) {
            return member.role;
          }
        }
        return 'member';
      },
      orElse: () => null,
    );
    final isWorkspaceAdmin =
        workspaceRole == 'admin' || workspaceRole == 'super_admin';

    return Scaffold(
      body: Stack(
        children: [
          const _ProfileGlow(),
          SafeArea(
            child: Column(
              children: [
                _ProfileTopBar(section: activeSection),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final nav = _ProfileNav(
                        activeSection: activeSection,
                        showAdminLink: isWorkspaceAdmin,
                      );
                      final content = _ProfileContent(
                        section: activeSection,
                        user: user,
                        workspaceRole: workspaceRole,
                      );

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 220, child: nav),
                            Expanded(child: content),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          nav,
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
        color: tokens.background.withValues(alpha: tokens.isDark ? 0.82 : 0.74),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 4),
          Text('SETTINGS', style: _eyebrowStyle(context)),
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
              _sectionTitle(section),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNav extends StatelessWidget {
  const _ProfileNav({required this.activeSection, required this.showAdminLink});

  final String activeSection;
  final bool showAdminLink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final items = <_NavItem>[
      const _NavItem('account', 'Account', Icons.person_outline_rounded),
      const _NavItem('appearance', 'Appearance', Icons.palette_outlined),
      const _NavItem(
        'notifications',
        'Notifications',
        Icons.notifications_none,
      ),
      if (showAdminLink)
        const _NavItem(
          'admin-link',
          'Admin console',
          Icons.admin_panel_settings_outlined,
          href: '/admin',
        ),
      const _NavItem(
        'danger',
        'Danger zone',
        Icons.warning_amber_rounded,
        danger: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: MediaQuery.sizeOf(context).width >= 900
              ? BorderSide(color: tokens.border)
              : BorderSide.none,
          bottom: MediaQuery.sizeOf(context).width < 900
              ? BorderSide(color: tokens.border)
              : BorderSide.none,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: MediaQuery.sizeOf(context).width >= 900
            ? Axis.vertical
            : Axis.horizontal,
        padding: const EdgeInsets.all(14),
        child: Flex(
          direction: MediaQuery.sizeOf(context).width >= 900
              ? Axis.vertical
              : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: _NavButton(
                  item: item,
                  active: item.key == activeSection,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active});

  final _NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final color = active
        ? tokens.accent
        : item.danger
        ? tokens.danger
        : tokens.text;

    return InkWell(
      onTap: () => context.go(item.href ?? '/profile/${item.key}'),
      borderRadius: BorderRadius.circular(tokens.radius.clamp(0, 10)),
      child: Container(
        width: MediaQuery.sizeOf(context).width >= 900 ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? tokens.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radius.clamp(0, 10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 18,
              color: active
                  ? tokens.accent
                  : item.danger
                  ? tokens.danger
                  : tokens.dim,
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.href != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.north_east_rounded, size: 13, color: tokens.faint),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.section,
    required this.user,
    required this.workspaceRole,
  });

  final String section;
  final User user;
  final String? workspaceRole;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: switch (section) {
            'appearance' => const _AppearanceSection(),
            'notifications' => const _NotificationsSection(),
            'danger' => _DangerSection(user: user),
            _ => _AccountSection(user: user, workspaceRole: workspaceRole),
          },
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.user, required this.workspaceRole});

  final User user;
  final String? workspaceRole;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final isWorkspaceAdmin =
        workspaceRole == 'admin' || workspaceRole == 'super_admin';
    final memberSince = DateFormat.yMMMM().format(user.createdAt);
    final roleLabel = _workspaceRoleLabel(workspaceRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Account',
          subtitle: 'Your profile inside this workspace.',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarUpload(user: user),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditableHeading(user: user),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.email,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.dim),
                      ),
                      if (isWorkspaceAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            roleLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: tokens.surfaceDecoration(),
          child: Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _MetaItem(label: 'Member since', value: memberSince),
              _MetaItem(
                label: 'Timezone',
                value: user.timezone.replaceAll('_', ' '),
              ),
              _MetaItem(label: 'Role', value: roleLabel),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const _FieldGroupLabel('Profile'),
        _InlineTitleField(user: user),
        _ReadOnlyField(
          label: 'Email',
          value: user.email,
          hint: 'Managed by your Google account',
        ),
        _ReadOnlyField(
          label: 'Timezone',
          value: user.timezone.replaceAll('_', ' '),
          hint: 'Detected from your browser',
        ),
      ],
    );
  }
}

class _EditableHeading extends ConsumerStatefulWidget {
  const _EditableHeading({required this.user});

  final User user;

  @override
  ConsumerState<_EditableHeading> createState() => _EditableHeadingState();
}

class _EditableHeadingState extends ConsumerState<_EditableHeading> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.user.name);
  }

  @override
  void didUpdateWidget(covariant _EditableHeading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.user.name != widget.user.name) {
      _controller.text = widget.user.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _CancelEditIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _CancelEditIntent: CallbackAction<_CancelEditIntent>(
              onInvoke: (_) {
                _cancel();
                return null;
              },
            ),
          },
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            enabled: !_saving,
            maxLength: 200,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.only(bottom: 4),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: context.maia.accent),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.maia.accent),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.maia.accent),
              ),
            ),
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _commit(),
          ),
        ),
      );
    }

    return InkWell(
      onTap: _start,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          widget.user.name,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _start() {
    setState(() {
      _editing = true;
      _controller.text = widget.user.name;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _cancel() {
    setState(() {
      _controller.text = widget.user.name;
      _editing = false;
      _saving = false;
    });
  }

  Future<void> _commit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || name == widget.user.name || _saving) {
      _cancel();
      return;
    }
    setState(() => _saving = true);
    try {
      final user = await ref
          .read(userServiceProvider)
          .update(widget.user.id, name: name);
      if (user != null) {
        await ref.read(authControllerProvider.notifier).updateUser(user);
      }
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack(context, _messageFor(error));
      }
    }
  }
}

class _InlineTitleField extends ConsumerStatefulWidget {
  const _InlineTitleField({required this.user});

  final User user;

  @override
  ConsumerState<_InlineTitleField> createState() => _InlineTitleFieldState();
}

class _InlineTitleFieldState extends ConsumerState<_InlineTitleField> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.user.title);
  }

  @override
  void didUpdateWidget(covariant _InlineTitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.user.title != widget.user.title) {
      _controller.text = widget.user.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return _EditableRowFrame(
        label: 'Title / role',
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.escape): _CancelEditIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _CancelEditIntent: CallbackAction<_CancelEditIntent>(
                onInvoke: (_) {
                  _cancel();
                  return null;
                },
              ),
            },
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              enabled: !_saving,
              maxLength: 64,
              decoration: const InputDecoration(
                hintText: 'e.g. Engineering Manager',
                counterText: '',
              ),
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
            ),
          ),
        ),
      );
    }

    return _ClickableField(
      label: 'Title / role',
      value: widget.user.title.isEmpty ? 'Add a title' : widget.user.title,
      placeholder: widget.user.title.isEmpty,
      onTap: _start,
    );
  }

  void _start() {
    setState(() {
      _editing = true;
      _controller.text = widget.user.title;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _cancel() {
    setState(() {
      _controller.text = widget.user.title;
      _editing = false;
      _saving = false;
    });
  }

  Future<void> _commit() async {
    final title = _controller.text.trim();
    if (title == widget.user.title || _saving) {
      _cancel();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateTitle(title);
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack(context, _messageFor(error));
      }
    }
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref
        .watch(themeControllerProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MaiaThemeSelection(),
        );
    final controller = ref.read(themeControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Appearance',
          subtitle: 'Choose how Maia looks to you.',
        ),
        const _FieldGroupLabel('Mode'),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: context.maia.surfaceDecoration(),
          child: SegmentedButton<MaiaThemeMode>(
            segments: const [
              ButtonSegment(
                value: MaiaThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: MaiaThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {selection.mode},
            onSelectionChanged: (modes) => controller.setMode(modes.first),
          ),
        ),
        const SizedBox(height: 28),
        const _FieldGroupLabel('Theme'),
        Column(
          children: [
            for (final theme in MaiaThemeKey.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ThemeCard(
                  theme: theme,
                  mode: selection.mode,
                  selected: selection.theme == theme,
                  onTap: () => controller.setTheme(theme),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MaiaThemeKey theme;
  final MaiaThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final preview = MaiaThemeTokens.resolve(theme, mode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final previewPanel = Container(
          width: compact ? double.infinity : 170,
          height: compact ? 96 : 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: preview.background,
            borderRadius: compact
                ? BorderRadius.vertical(top: Radius.circular(tokens.radius))
                : BorderRadius.horizontal(left: Radius.circular(tokens.radius)),
            border: compact
                ? Border(bottom: BorderSide(color: preview.border))
                : Border(right: BorderSide(color: preview.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: preview.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: preview.text.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Aa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: preview.text,
                  fontFamily: _previewFontFamily(context, preview),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 72,
                height: 5,
                decoration: BoxDecoration(
                  color: preview.dim.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: preview.faint,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        );
        final labelPanel = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      theme.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Text(
                      'CURRENT',
                      style: _eyebrowStyle(
                        context,
                      ).copyWith(color: tokens.accent),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                theme.blurb,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.dim),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _ColorDot(color: preview.accent, label: 'accent'),
                  _ColorDot(color: preview.success, label: 'success'),
                  _ColorDot(color: preview.danger, label: 'danger'),
                ],
              ),
            ],
          ),
        );
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius),
          child: Container(
            decoration: tokens
                .surfaceDecoration(withShadow: selected)
                .copyWith(
                  color: selected ? tokens.accentSoft : tokens.backgroundCard,
                  border: Border.all(
                    color: selected ? tokens.accent : tokens.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [previewPanel, labelPanel],
                  )
                : Row(
                    children: [
                      previewPanel,
                      Expanded(child: labelPanel),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Notifications',
          subtitle: 'How Maia reaches out to you.',
        ),
        const _FieldGroupLabel('Channels'),
        const _ToggleField(label: 'Push', hint: 'Browser push notifications'),
        const _ToggleField(label: 'Email', hint: 'Daily digest and mentions'),
        const SizedBox(height: 22),
        const _FieldGroupLabel('When'),
        const _ToggleField(
          label: 'Daily check-in reminder',
          hint: "Remind me if I haven't responded within an hour",
        ),
        const _ToggleField(
          label: 'Team activity',
          hint: 'Relays and blockers from the team',
        ),
        const SizedBox(height: 16),
        _DashedNote(
          icon: Icons.notifications_paused_outlined,
          text:
              'Notifications are coming soon. Toggles are placeholders for now.',
        ),
      ],
    );
  }
}

class _DangerSection extends ConsumerWidget {
  const _DangerSection({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Danger zone',
          subtitle: 'Destructive actions. Double-check before acting.',
        ),
        _DangerRow(
          title: 'Sign out',
          hint: "You'll need to sign in again on this device.",
          actionLabel: 'Sign out',
          onAction: () => ref.read(authControllerProvider.notifier).logout(),
        ),
        _DangerRow(
          title: 'Revoke all sessions',
          hint: "Sign out of every device where you're logged in.",
          actionLabel: 'Revoke',
          onAction: () => ref.read(authControllerProvider.notifier).logout(),
        ),
        _DangerRow(
          title: 'Delete account',
          hint:
              'Permanently delete ${user.email} and remove it from all projects. This cannot be undone.',
          actionLabel: 'Delete',
          severity: _DangerSeverity.danger,
          onAction: () =>
              _showSnack(context, 'Account deletion not yet enabled.'),
        ),
      ],
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onAction,
    this.severity = _DangerSeverity.warn,
  });

  final String title;
  final String hint;
  final String actionLabel;
  final VoidCallback onAction;
  final _DangerSeverity severity;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final isDanger = severity == _DangerSeverity.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: tokens.surfaceDecoration().copyWith(
        color: isDanger
            ? Color.alphaBlend(
                tokens.danger.withValues(alpha: 0.06),
                tokens.backgroundCard,
              )
            : tokens.backgroundCard,
        border: Border.all(
          color: isDanger
              ? tokens.danger.withValues(alpha: 0.28)
              : tokens.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          isDanger
              ? FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(
                      color: tokens.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.maia.dim),
          ),
        ],
      ),
    );
  }
}

class _FieldGroupLabel extends StatelessWidget {
  const _FieldGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label.toUpperCase(), style: _eyebrowStyle(context)),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: _eyebrowStyle(context)),
        const SizedBox(width: 7),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ClickableField extends StatelessWidget {
  const _ClickableField({
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.maia.radius),
      child: _FieldShell(label: label, value: value, placeholder: placeholder),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(label: label, value: value, hint: hint);
  }
}

class _EditableRowFrame extends StatelessWidget {
  const _EditableRowFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: tokens.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.label,
    required this.value,
    this.hint,
    this.placeholder = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: tokens.surfaceDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: placeholder ? tokens.faint : tokens.text,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.faint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarUpload extends StatelessWidget {
  const _AvatarUpload({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _ProfileAvatar(user: user, radius: 44),
        Positioned(
          right: -2,
          bottom: -2,
          child: Tooltip(
            message: 'Avatar upload coming soon',
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tokens.accent,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.background, width: 2),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                size: 15,
                color: tokens.accentInk,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.radius});

  final User user;
  final double radius;

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
      radius: radius,
      foregroundImage: user.avatarUrl == null
          ? null
          : NetworkImage(user.avatarUrl!),
      backgroundColor: context.maia.accentSoft,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: context.maia.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileGlow extends StatelessWidget {
  const _ProfileGlow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.7, -0.75),
            radius: 1.05,
            colors: [
              tokens.accent.withValues(alpha: tokens.isDark ? 0.07 : 0.11),
              tokens.background,
            ],
            stops: const [0, 0.72],
          ),
        ),
      ),
    );
  }
}

class _ToggleField extends StatelessWidget {
  const _ToggleField({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: tokens.surfaceDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.dim),
                ),
              ],
            ),
          ),
          Switch(value: true, onChanged: null),
        ],
      ),
    );
  }
}

class _DashedNote extends StatelessWidget {
  const _DashedNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.backgroundCard,
        borderRadius: tokens.borderRadius,
        border: Border.all(color: tokens.border, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(icon, color: tokens.faint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.dim),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(
    this.key,
    this.label,
    this.icon, {
    this.href,
    this.danger = false,
  });

  final String key;
  final String label;
  final IconData icon;
  final String? href;
  final bool danger;
}

class _CancelEditIntent extends Intent {
  const _CancelEditIntent();
}

enum _DangerSeverity { warn, danger }

String _sectionTitle(String section) {
  return switch (section) {
    'appearance' => 'Appearance',
    'notifications' => 'Notifications',
    'danger' => 'Danger zone',
    _ => 'Account',
  };
}

String _workspaceRoleLabel(String? role) {
  return switch (role) {
    'super_admin' => 'Workspace owner',
    'admin' => 'Workspace admin',
    _ => 'Member',
  };
}

String _messageFor(Object error) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Request failed. Please try again.';
}

String? _previewFontFamily(BuildContext context, MaiaThemeTokens tokens) {
  return switch (tokens.displayFont) {
    MaiaFontFamily.dmSans => Theme.of(context).textTheme.bodyMedium?.fontFamily,
    MaiaFontFamily.dmMono => Theme.of(context).textTheme.labelSmall?.fontFamily,
    MaiaFontFamily.fraunces => Theme.of(
      context,
    ).textTheme.titleLarge?.fontFamily,
    MaiaFontFamily.jetBrainsMono => Theme.of(
      context,
    ).textTheme.labelSmall?.fontFamily,
  };
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
