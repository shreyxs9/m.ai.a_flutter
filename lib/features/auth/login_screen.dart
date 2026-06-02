import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 960;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 40 : 20,
                vertical: desktop ? 24 : 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LandingHeader(onLogin: _loading ? null : _launchLogin),
                      SizedBox(height: desktop ? 54 : 34),
                      _LandingHero(
                        desktop: desktop,
                        loading: _loading,
                        authError: auth?.error,
                        localError: _error,
                        onLogin: _loading ? null : _launchLogin,
                      ),
                      SizedBox(height: desktop ? 72 : 44),
                      const _FlowSection(),
                      SizedBox(height: desktop ? 72 : 44),
                      const _ProductSurfacesSection(),
                      SizedBox(height: desktop ? 72 : 44),
                      _ExampleSection(desktop: desktop),
                      SizedBox(height: desktop ? 72 : 44),
                      _ClosingSection(
                        loading: _loading,
                        onLogin: _loading ? null : _launchLogin,
                      ),
                      const SizedBox(height: 28),
                      const _LandingFooter(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _launchLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final config = ApiConfig.defaultConfig;
    final url = config.loginRedirectUrl(
      redirectUri: kIsWeb ? null : config.mobileRedirectUri,
    );
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

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.onLogin});

  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: tokens.accentSurfaceDecoration().copyWith(
            borderRadius: BorderRadius.circular(tokens.radius + 6),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: tokens.accent),
        ),
        const SizedBox(width: 10),
        Text(
          'M.AI.A',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.text,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login_rounded, size: 17),
          label: const Text('Sign in'),
        ),
      ],
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({
    required this.desktop,
    required this.loading,
    required this.authError,
    required this.localError,
    required this.onLogin,
  });

  final bool desktop;
  final bool loading;
  final String? authError;
  final String? localError;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final textTheme = Theme.of(context).textTheme;
    final pitch = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Kicker('Async check-ins + daily digest'),
        const SizedBox(height: 18),
        Text(
          'Alignment, on autopilot',
          style: (desktop ? textTheme.displayLarge : textTheme.displayMedium)
              ?.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
                height: 1.04,
              ),
        ),
        const SizedBox(height: 18),
        Text(
          "Maia checks in with each teammate on your cadence, turns the day's progress into one clear digest, and surfaces blockers before they cost you the week so standups start with everyone already on the same page.",
          style: textTheme.bodyLarge?.copyWith(
            color: tokens.dim,
            height: 1.55,
            fontWeight: FontWeight.w300,
          ),
        ),
        if (authError != null || localError != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: tokens.dangerSurfaceDecoration(),
            child: Text(
              localError ?? authError!,
              style: textTheme.bodySmall?.copyWith(
                color: tokens.danger,
                height: 1.35,
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onLogin,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded, size: 18),
              label: Text(
                loading ? 'Opening sign in' : "Get started - it's free",
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _scrollToHowItWorks(context),
              icon: const Icon(Icons.route_rounded, size: 18),
              label: const Text('See how it works'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Async by design | no nagging | live in minutes',
          style: textTheme.labelSmall?.copyWith(
            color: tokens.faint,
            fontFamily: Theme.of(context).textTheme.labelSmall?.fontFamily,
          ),
        ),
      ],
    );

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [pitch, const SizedBox(height: 28), const _HeroProductMock()],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 11, child: pitch),
        const SizedBox(width: 44),
        const Expanded(flex: 9, child: _HeroProductMock()),
      ],
    );
  }

  void _scrollToHowItWorks(BuildContext context) {
    Scrollable.ensureVisible(
      _FlowSection.anchorKey.currentContext ?? context,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }
}

class _HeroProductMock extends StatelessWidget {
  const _HeroProductMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CheckinSurface(),
        const SizedBox(height: 16),
        const FractionallySizedBox(
          widthFactor: 0.88,
          alignment: Alignment.centerRight,
          child: _DigestSurface(),
        ),
      ],
    );
  }
}

class _FlowSection extends StatelessWidget {
  const _FlowSection();

  static final anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 760;
    final cards = [
      const _StepCard(
        number: '01',
        title: 'Maia checks in',
        body:
            "A short, friendly message at your team's chosen time: async, on their schedule, and focused on what moved.",
      ),
      const _StepCard(
        number: '02',
        title: 'You get the digest',
        body:
            "Every day, one clean rollup lands: what shipped, what's in flight, and exactly what needs your eyes.",
      ),
      const _StepCard(
        number: '03',
        title: 'Blockers get unblocked',
        body:
            "Maia spots who's stuck and routes the right context to whoever can help before it becomes next week's problem.",
      ),
    ];

    return _SectionShell(
      key: anchorKey,
      kicker: 'How it works',
      title: 'Three steps. Then it runs without you.',
      child: Flex(
        direction: desktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in cards.indexed) ...[
            if (desktop) Expanded(child: entry.$2) else entry.$2,
            if (entry.$1 != cards.length - 1) _StepGap(desktop: desktop),
          ],
        ],
      ),
    );
  }
}

class _StepGap extends StatelessWidget {
  const _StepGap({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: desktop ? 12 : 0, height: desktop ? 0 : 12);
  }
}

class _ProductSurfacesSection extends StatelessWidget {
  const _ProductSurfacesSection();

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 920;
    return _SectionShell(
      kicker: 'Real product surfaces',
      title: 'More than a check-in. A whole calm workflow.',
      body:
          'These are the real surfaces Maia drops into your thread whether your team runs marketing campaigns, sales pipelines, client work, PR launches, or product. Same calm workflow, any function.',
      child: GridView.count(
        crossAxisCount: desktop ? 2 : 1,
        childAspectRatio: desktop ? 1.22 : 0.92,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: const [
          _SurfaceTile(
            title: 'The daily pulse',
            body:
                "One project-wide read every day with a red, yellow, or green call: what shipped, what's at risk, and who's gone quiet.",
            child: _DailyPulseMini(),
          ),
          _SurfaceTile(
            title: 'Relays - ask without the ping-storm',
            body:
                'Mention a teammate and Maia rephrases the ask, delivers it, and threads the reply back.',
            child: _RelayMini(),
          ),
          _SurfaceTile(
            title: 'Broadcasts to everyone',
            body:
                "One project-wide message, politely rephrased and delivered to each person's thread, never a noisy channel blast.",
            child: _BroadcastMini(),
          ),
          _SurfaceTile(
            title: 'Goals and state, always current',
            body:
                'Your north star stays pinned, and Maia keeps a living read of where the project actually is from every check-in.',
            child: _GoalsStateMini(),
          ),
        ],
      ),
    );
  }
}

class _ExampleSection extends StatelessWidget {
  const _ExampleSection({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final examples = [
      (
        'Marketing launch',
        'Creative, PR, lifecycle, and analytics stay synced without a status meeting.',
      ),
      (
        'Sales pipeline',
        'AEs, solutions, legal, and customer success see risks before the renewal call.',
      ),
      (
        'Client delivery',
        'Design, engineering, PM, and ops keep handoffs visible across time zones.',
      ),
      (
        'Product sprint',
        'Roadmap changes, blockers, and shipped work roll into one daily read.',
      ),
    ];
    return _SectionShell(
      kicker: 'Cross-functional examples',
      title: 'Built for teams where work crosses functions.',
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final example in examples)
            SizedBox(
              width: desktop ? 270 : double.infinity,
              child: _ExampleCard(title: example.$1, body: example.$2),
            ),
        ],
      ),
    );
  }
}

class _ClosingSection extends StatelessWidget {
  const _ClosingSection({required this.loading, required this.onLogin});

  final bool loading;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
      decoration: tokens.surfaceDecoration(withShadow: true),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, color: tokens.accent, size: 34),
          const SizedBox(height: 14),
          Text(
            'Give your team its calmest week yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Free to start. Spin up your first project and run a check-in in under five minutes. No credit card, no setup call.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.dim, height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onLogin,
            icon: loading
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded, size: 18),
            label: Text(loading ? 'Opening sign in' : 'Get started'),
          ),
        ],
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final year = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Flex(
        direction: MediaQuery.sizeOf(context).width >= 640
            ? Axis.horizontal
            : Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '(c) $year Cydratech Private Limited',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.faint, height: 1.4),
          ),
          const SizedBox(width: 16, height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _FooterLink(label: 'Privacy'),
              _FooterLink(label: 'Terms'),
              _FooterLink(label: 'Contact'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: tokens.dim,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    super.key,
    required this.kicker,
    required this.title,
    this.body,
    required this.child,
  });

  final String kicker;
  final String title;
  final String? body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Kicker(kicker),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.16,
            ),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              body!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.dim, height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.accent,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: tokens.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.dim, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({
    required this.title,
    required this.body,
    required this.child,
  });

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      decoration: tokens.surfaceDecoration(withShadow: true),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(18),
              color: tokens.backgroundRaised.withValues(alpha: 0.54),
              child: child,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.dim,
                    height: 1.45,
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

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: tokens.raisedSurfaceDecoration(withBorder: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hub_outlined, color: tokens.accent, size: 20),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.dim, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CheckinSurface extends StatelessWidget {
  const _CheckinSurface();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: tokens.surfaceDecoration(withShadow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SurfaceEyebrow(icon: Icons.auto_awesome, label: 'check-in'),
          const SizedBox(height: 8),
          const _ChatBubble(
            text: 'Morning, Priya. How is the Q3 launch coming along?',
            outbound: false,
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerRight,
            child: _ChatBubble(
              text:
                  "Landing page copy is approved. Still waiting on final creative from design.",
              outbound: true,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'FLAGGED',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.danger,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          _ChatBubble(
            text:
                'Noted. I am flagging the creative handoff and looping in Devon, who runs the design queue.',
            outbound: false,
            tone: tokens.danger,
          ),
        ],
      ),
    );
  }
}

class _DigestSurface extends StatelessWidget {
  const _DigestSurface();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: tokens.surfaceDecoration(withShadow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_rounded, size: 16, color: tokens.danger),
              const SizedBox(width: 7),
              Text(
                'Priya | daily check-in',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DigestLine(color: tokens.success, text: '2 done'),
          _DigestLine(color: tokens.danger, text: '2 blockers'),
          _DigestLine(color: tokens.accent, text: '1 next'),
          const SizedBox(height: 8),
          _DigestLine(
            color: tokens.success,
            text: 'Done: newsletter drafted and Q3 ad copy approved',
          ),
          _DigestLine(
            color: tokens.danger,
            text: 'Blocked: final hero creative still pending from design',
          ),
          _DigestLine(color: tokens.accent, text: 'Next: brief the PR agency'),
        ],
      ),
    );
  }
}

class _DailyPulseMini extends StatelessWidget {
  const _DailyPulseMini();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.08),
        borderRadius: tokens.borderRadius,
        border: Border.all(color: tokens.accent.withValues(alpha: 0.65)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RiskPill(label: 'yellow', color: tokens.accent),
          const SizedBox(height: 10),
          const _MiniBullet('4 of 5 on the launch checked in.'),
          const _MiniBullet(
            'Shipped: newsletter scheduled, press list locked.',
          ),
          const _MiniBullet('Watch: hero creative routed to Devon.'),
        ],
      ),
    );
  }
}

class _RelayMini extends StatelessWidget {
  const _RelayMini();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pill(icon: Icons.north_east_rounded, text: 'Relayed via Maia'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.backgroundCard,
            borderRadius: tokens.borderRadius,
            border: Border.all(color: tokens.accent),
          ),
          child: Text(
            'When you get a sec, can you pull the latest pricing deck? The Acme renewal call is at 3.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.dim,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _BroadcastMini extends StatelessWidget {
  const _BroadcastMini();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SurfaceEyebrow(
          icon: Icons.campaign_rounded,
          label: 'broadcast to everyone',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: tokens.surfaceDecoration(),
          child: Text(
            'Heads up team: embargo lifts 9am ET. Please push the launch posts then.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _GoalsStateMini extends StatelessWidget {
  const _GoalsStateMini();

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: tokens.surfaceDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SurfaceEyebrow(icon: Icons.flag_outlined, label: 'goals'),
          const SizedBox(height: 8),
          Text(
            'Grow qualified pipeline 30% this quarter',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const _SurfaceEyebrow(icon: Icons.timeline_outlined, label: 'state'),
          const SizedBox(height: 8),
          Text(
            'Mid-launch on the rebrand. Press outreach is underway; legal sign-off on campaign claims may slip social rollout.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.dim, height: 1.45),
          ),
          const SizedBox(height: 10),
          _RiskPill(label: 'auto-evolved', color: tokens.faint),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.outbound, this.tone});

  final String text;
  final bool outbound;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final color = tone;
    return Container(
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: outbound
            ? tokens.accent
            : color?.withValues(alpha: 0.10) ?? tokens.backgroundCard,
        borderRadius: BorderRadius.circular(tokens.radius + 6).copyWith(
          bottomLeft: outbound ? null : const Radius.circular(6),
          bottomRight: outbound ? const Radius.circular(6) : null,
        ),
        border: outbound
            ? null
            : Border.all(
                color: color?.withValues(alpha: 0.30) ?? tokens.border,
              ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: outbound ? tokens.accentInk : tokens.text,
          height: 1.45,
        ),
      ),
    );
  }
}

class _DigestLine extends StatelessWidget {
  const _DigestLine({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.dim, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceEyebrow extends StatelessWidget {
  const _SurfaceEyebrow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tokens.accent),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tokens.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniBullet extends StatelessWidget {
  const _MiniBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        '- $text',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.text, height: 1.35),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: tokens.surfaceDecoration(
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tokens.accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
