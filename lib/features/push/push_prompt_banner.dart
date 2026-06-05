import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/public_web_config.dart';
import '../../core/push/browser_push.dart';
import '../../core/theme/maia_theme_helpers.dart';

class PushPromptBanner extends ConsumerStatefulWidget {
  const PushPromptBanner({super.key, this.suppressed = false});

  final bool suppressed;

  @override
  ConsumerState<PushPromptBanner> createState() => _PushPromptBannerState();
}

class _PushPromptBannerState extends ConsumerState<PushPromptBanner> {
  BrowserPushStatus? _status;
  bool _busy = false;
  bool _hidden = false;
  bool _routeSettled = false;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    _settleTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _routeSettled = true);
      }
    });
    unawaited(_checkSilently());
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSilently() async {
    final result = await ensureBrowserPushSubscription(
      promptIfDefault: false,
      firebaseConfig: PublicWebConfig.firebaseConfig,
    );
    if (!mounted) {
      return;
    }
    setState(() => _status = result.status);
    if (result.status == BrowserPushStatus.subscribed && result.token != null) {
      await _registerToken(result.token!);
    }
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final result = await ensureBrowserPushSubscription(
      promptIfDefault: true,
      firebaseConfig: PublicWebConfig.firebaseConfig,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _status = result.status;
      _hidden = result.status == BrowserPushStatus.subscribed;
      _busy = false;
    });
    if (result.status == BrowserPushStatus.subscribed && result.token != null) {
      await _registerToken(result.token!);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await ref
          .read(pushServiceProvider)
          .registerToken(token, detectPushPlatform());
    } catch (_) {
      if (mounted) {
        setState(() => _status = BrowserPushStatus.error);
      }
    }
  }

  void _dismiss() {
    markPushDismissed();
    setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).asData?.value;
    final status = _status;
    final visible =
        _routeSettled &&
        !widget.suppressed &&
        !_hidden &&
        auth?.isAuthenticated == true &&
        status != null &&
        status != BrowserPushStatus.subscribed &&
        status != BrowserPushStatus.unsupported &&
        status != BrowserPushStatus.permissionDenied &&
        status != BrowserPushStatus.error &&
        !isPushDismissedRecently();

    final isInstallHint = status == BrowserPushStatus.needsInstall;
    final tokens = context.maia;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 0.18),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: tokens.backgroundCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.border),
                      boxShadow: tokens.shadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isInstallHint
                                        ? 'Add M.AI.A to your home screen for check-in reminders'
                                        : 'Get a heads-up at check-in time?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: tokens.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    isInstallHint
                                        ? 'In Safari, use Share, then Add to Home Screen. iOS only allows web push from installed sites.'
                                        : 'A small notification when Maia starts your daily check-in. Goes to whichever devices you allow.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: tokens.faint,
                                          height: 1.3,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _busy ? null : _dismiss,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (!isInstallHint) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: _busy ? null : _enable,
                                child: Text(_busy ? 'Enabling...' : 'Enable'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _busy ? null : _dismiss,
                                child: const Text('Not now'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
