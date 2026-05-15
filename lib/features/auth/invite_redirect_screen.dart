import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/browser_url.dart';
import '../../core/network/network.dart';

class InviteRedirectScreen extends ConsumerStatefulWidget {
  const InviteRedirectScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<InviteRedirectScreen> createState() =>
      _InviteRedirectScreenState();
}

class _InviteRedirectScreenState extends ConsumerState<InviteRedirectScreen> {
  String _status = 'Joining project...';
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      Future<void>.microtask(_start);
    }
  }

  Future<void> _start() async {
    final normalized = ProjectService.normalizeInviteCode(widget.code);
    if (normalized.length != 6) {
      setState(() {
        _error = "That invite link doesn't look right.";
      });
      return;
    }

    final auth = ref.read(authControllerProvider).asData?.value;
    if (auth?.isAuthenticated != true) {
      await ref.read(apiSessionStoreProvider).setPendingInvite(normalized);
      navigateBrowserTo(ApiConfig.defaultConfig.loginRedirectUrl);
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final result =
          await ref.read(projectServiceProvider).joinByInvite(normalized);
      if (result == null) {
        throw const ApiException(null, "Couldn't redeem invite.");
      }

      await ref.read(authControllerProvider.notifier).selectTenantId(
            result.tenantId,
          );
      await ref.read(authControllerProvider.notifier).refreshTenants();

      if (!mounted) {
        return;
      }
      context.go('/project/${result.projectId}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is ApiException
            ? error.message
            : "Couldn't redeem invite.";
        _status = 'Invite failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _error == null
                    ? Icons.link_rounded
                    : Icons.error_outline_rounded,
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(_error ?? _status, textAlign: TextAlign.center),
              if (_error != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
