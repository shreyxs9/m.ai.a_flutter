import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/browser_url.dart';
import '../../core/network/network.dart';
import '../../core/theme/maia_theme_helpers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).asData?.value;
    final tokens = context.maia;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                decoration: tokens.surfaceDecoration(withShadow: true),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: tokens.accentSoft,
                          borderRadius: BorderRadius.circular(
                            tokens.radius + 10,
                          ),
                          border: Border.all(color: tokens.glassBorder),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 36,
                          color: tokens.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'M.AI.A',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'a quieter way to stay in sync',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.dim,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (auth?.error != null || _error != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: tokens.dangerSurfaceDecoration(),
                        child: Text(
                          _error ?? auth!.error!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.danger,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loading ? null : _launchLogin,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded, size: 18),
                      label: Text(
                        _loading ? 'Opening sign in' : 'Continue with Google',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final url = ApiConfig.defaultConfig.loginRedirectUrl;
    try {
      navigateBrowserTo(url);
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasScheme) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Could not start sign in. Please try again.';
      });
    }
  }
}
