import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../models/models.dart';

class ProjectContextPanel extends ConsumerStatefulWidget {
  const ProjectContextPanel({
    required this.projectId,
    required this.isAdmin,
    this.refreshTick = 0,
    super.key,
  });

  final String projectId;
  final bool isAdmin;
  final int refreshTick;

  @override
  ConsumerState<ProjectContextPanel> createState() =>
      _ProjectContextPanelState();
}

class _ProjectContextPanelState extends ConsumerState<ProjectContextPanel> {
  ProjectGoals? _goals;
  ProjectState? _state;
  List<ProjectGoalsHistoryItem> _goalsHistory =
      const <ProjectGoalsHistoryItem>[];
  List<ProjectStateHistoryItem> _stateHistory =
      const <ProjectStateHistoryItem>[];
  bool _loading = true;
  bool _goalsHistoryOpen = false;
  bool _stateHistoryOpen = false;
  int _goalsHistoryIndex = 0;
  int _stateHistoryIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ProjectContextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.refreshTick != widget.refreshTick) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final base = await Future.wait<Object?>([
        ref.read(projectServiceProvider).goals(widget.projectId),
        ref.read(projectServiceProvider).state(widget.projectId),
      ]);
      List<ProjectGoalsHistoryItem> goalsHistory =
          const <ProjectGoalsHistoryItem>[];
      List<ProjectStateHistoryItem> stateHistory =
          const <ProjectStateHistoryItem>[];
      if (widget.isAdmin) {
        final history = await Future.wait<Object?>([
          ref.read(projectServiceProvider).goalsHistory(widget.projectId),
          ref.read(projectServiceProvider).stateHistory(widget.projectId),
        ]);
        goalsHistory = history[0] as List<ProjectGoalsHistoryItem>;
        stateHistory = history[1] as List<ProjectStateHistoryItem>;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _goals = base[0] as ProjectGoals?;
        _state = base[1] as ProjectState?;
        _goalsHistory = goalsHistory;
        _stateHistory = stateHistory;
        _goalsHistoryIndex = _goalsHistoryIndex.clamp(
          0,
          (_goalsHistory.length - 1).clamp(0, 9999),
        );
        _stateHistoryIndex = _stateHistoryIndex.clamp(
          0,
          (_stateHistory.length - 1).clamp(0, 9999),
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final displayedGoals = _goalsHistoryOpen && _goalsHistory.isNotEmpty
        ? _goalsHistory[_goalsHistoryIndex].goals
        : _goals?.goals ?? const <String>[];
    final displayedState = _stateHistoryOpen && _stateHistory.isNotEmpty
        ? _stateHistory[_stateHistoryIndex].body
        : _state?.body;
    final stateAutoEvolved = _stateHistoryOpen && _stateHistory.isNotEmpty
        ? _stateHistory[_stateHistoryIndex].autoEvolved
        : (displayedState?.isNotEmpty == true && _state?.changedBy == null);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContextSection(
            title: 'Goals',
            subtitle: 'What we are aiming at',
            count: displayedGoals.length,
            loading: _loading,
            historyVisible: widget.isAdmin && _goalsHistory.length > 1,
            historyOpen: _goalsHistoryOpen,
            onToggleHistory: () {
              setState(() {
                _goalsHistoryOpen = !_goalsHistoryOpen;
                _goalsHistoryIndex = 0;
              });
            },
            revisionNav: _goalsHistoryOpen && _goalsHistory.length > 1
                ? _RevisionNav(
                    current: _goalsHistoryIndex,
                    total: _goalsHistory.length,
                    onChanged: (value) {
                      setState(() => _goalsHistoryIndex = value);
                    },
                  )
                : null,
            child: displayedGoals.isEmpty
                ? _EmptyHint(
                    text: widget.isAdmin
                        ? 'No goals set yet. Ask Maia to set them.'
                        : 'No goals set yet.',
                  )
                : Column(
                    children: [
                      for (final entry in displayedGoals.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.$1 + 1}.',
                                style: TextStyle(
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.$2,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: tokens.text,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          Divider(height: 1, color: tokens.border),
          _ContextSection(
            title: 'State',
            subtitle: 'Where we are right now',
            loading: _loading,
            historyVisible: widget.isAdmin && _stateHistory.length > 1,
            historyOpen: _stateHistoryOpen,
            onToggleHistory: () {
              setState(() {
                _stateHistoryOpen = !_stateHistoryOpen;
                _stateHistoryIndex = 0;
              });
            },
            revisionNav: _stateHistoryOpen && _stateHistory.length > 1
                ? _RevisionNav(
                    current: _stateHistoryIndex,
                    total: _stateHistory.length,
                    onChanged: (value) {
                      setState(() => _stateHistoryIndex = value);
                    },
                  )
                : null,
            child: displayedState == null || displayedState.trim().isEmpty
                ? _EmptyHint(
                    text: widget.isAdmin
                        ? 'No state set yet. Ask Maia to set it.'
                        : 'No state set yet.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: tokens.accent, width: 2),
                          ),
                        ),
                        child: Text(
                          displayedState,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.text, height: 1.45),
                        ),
                      ),
                      if (stateAutoEvolved) ...[
                        const SizedBox(height: 8),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: tokens.accent,
                          ),
                          label: const Text('Auto-evolved'),
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

class _ContextSection extends StatelessWidget {
  const _ContextSection({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.historyVisible,
    required this.historyOpen,
    required this.onToggleHistory,
    required this.child,
    this.count,
    this.revisionNav,
  });

  final String title;
  final String subtitle;
  final int? count;
  final bool loading;
  final bool historyVisible;
  final bool historyOpen;
  final VoidCallback onToggleHistory;
  final Widget? revisionNav;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: tokens.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (count != null && count! > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '$count',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.faint),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.faint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (historyVisible)
                IconButton(
                  tooltip: historyOpen ? 'Current' : 'History',
                  onPressed: onToggleHistory,
                  icon: Icon(
                    historyOpen
                        ? Icons.update_disabled_rounded
                        : Icons.history_rounded,
                  ),
                ),
            ],
          ),
          if (revisionNav != null) ...[const SizedBox(height: 8), revisionNav!],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RevisionNav extends StatelessWidget {
  const _RevisionNav({
    required this.current,
    required this.total,
    required this.onChanged,
  });

  final int current;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Row(
      children: [
        Text(
          'Rev ${total - current} of $total',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: tokens.faint),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Older',
          onPressed: current >= total - 1
              ? null
              : () => onChanged((current + 1).clamp(0, total - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Newer',
          onPressed: current <= 0
              ? null
              : () => onChanged((current - 1).clamp(0, total - 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(
          onPressed: current == 0 ? null : () => onChanged(0),
          child: const Text('Now'),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.maia.faint, height: 1.35),
    );
  }
}
