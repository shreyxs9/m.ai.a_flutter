import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/browser_url.dart';
import '../../core/network/network.dart';
import '../../models/models.dart';

const _roleOptions = [
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

class WorkspaceJoinScreen extends ConsumerStatefulWidget {
  const WorkspaceJoinScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<WorkspaceJoinScreen> createState() =>
      _WorkspaceJoinScreenState();
}

class _WorkspaceJoinScreenState extends ConsumerState<WorkspaceJoinScreen> {
  TenantPreview? _workspace;
  String? _pickedRole;
  String _customRole = '';
  String? _error;
  bool _loading = true;
  bool _joining = false;
  bool _started = false;

  String get _normalized => ProjectService.normalizeInviteCode(widget.code);

  String get _role {
    return _pickedRole == '__custom' ? _customRole.trim() : _pickedRole ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    if (_normalized.length != 6) {
      setState(() {
        _loading = false;
        _error = "That workspace link doesn't look right.";
      });
      return;
    }

    final auth = ref.read(authControllerProvider).asData?.value;
    if (auth?.isAuthenticated != true) {
      await ref
          .read(apiSessionStoreProvider)
          .setPendingWorkspaceInvite(_normalized);
      navigateBrowserTo(ApiConfig.defaultConfig.loginRedirectUrl());
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final preview = await ref
          .read(tenantServiceProvider)
          .previewByInvite(_normalized);
      if (!mounted) {
        return;
      }
      setState(() {
        _workspace = preview;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : "We couldn't find that workspace.";
      });
    }
  }

  Future<void> _join() async {
    if (_workspace == null || _role.isEmpty || _joining) {
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(tenantServiceProvider)
          .joinByInvite(_normalized);
      if (result == null) {
        throw const ApiException(null, "Couldn't join workspace.");
      }
      if (result.joined) {
        await ref.read(authServiceProvider).updateTitle(_role);
      }
      await ref
          .read(authControllerProvider.notifier)
          .selectTenantId(result.tenantId);
      await ref.read(authControllerProvider.notifier).refreshTenants();
      if (mounted) {
        context.go('/');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joining = false;
        _error = error is ApiException
            ? error.message
            : "Couldn't join workspace.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && _workspace == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 36),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final workspace = _workspace;
    final alreadyMember = workspace?.alreadyMember ?? false;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment_rounded, size: 42),
                const SizedBox(height: 16),
                Text(
                  alreadyMember
                      ? "You're already in"
                      : "You've been invited to",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  workspace?.name ?? 'this workspace',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                if (alreadyMember)
                  FilledButton(
                    onPressed: _joining
                        ? null
                        : () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .selectTenantId(workspace!.id);
                            await ref
                                .read(authControllerProvider.notifier)
                                .refreshTenants();
                            if (context.mounted) {
                              context.go('/');
                            }
                          },
                    child: const Text('Open workspace'),
                  )
                else ...[
                  Text(
                    'Your role',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final role in _roleOptions)
                        ChoiceChip(
                          label: Text(role),
                          selected: _pickedRole == role,
                          onSelected: (_) => setState(() {
                            _pickedRole = role;
                          }),
                        ),
                      ChoiceChip(
                        label: const Text('Something else'),
                        selected: _pickedRole == '__custom',
                        onSelected: (_) => setState(() {
                          _pickedRole = '__custom';
                        }),
                      ),
                    ],
                  ),
                  if (_pickedRole == '__custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      maxLength: 64,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        hintText: 'e.g. Chief of Staff',
                      ),
                      onChanged: (value) => setState(() {
                        _customRole = value;
                      }),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _role.isEmpty || _joining ? null : _join,
                    child: _joining
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Join workspace'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
