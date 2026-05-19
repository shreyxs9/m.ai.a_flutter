import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../models/models.dart';
import '../projects/project_avatar_widget.dart';

const _pageSize = 100;
const _messageTypes = <String>{
  'maia_ask',
  'user_reply',
  'maia_note',
  'maia_relay',
  'maia_summary',
  'maia_digest',
};

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();

  ProjectWithMembers? _project;
  Thread? _thread;
  List<Message> _messages = const <Message>[];
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = false;
  bool _rightPanelOpen = true;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      setState(() {
        _project = null;
        _thread = null;
        _messages = const <Message>[];
        _error = null;
        _loading = true;
        _sending = false;
        _loadingOlder = false;
        _hasMoreOlder = false;
        _didInitialScroll = false;
      });
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final projectId = widget.projectId;
    if (projectId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing project id.';
      });
      return;
    }

    try {
      final results = await Future.wait<Object?>([
        ref.read(projectServiceProvider).get(projectId),
        ref.read(threadServiceProvider).getOrCreateForProject(projectId),
      ]);
      if (!mounted || projectId != widget.projectId) {
        return;
      }

      final project = results[0] as ProjectWithMembers?;
      final thread = results[1] as Thread?;
      if (project == null || thread == null) {
        throw const ApiException(null, 'Project chat could not be loaded.');
      }

      final messages = await ref
          .read(threadServiceProvider)
          .listMessages(thread.id, limit: _pageSize);
      if (!mounted || projectId != widget.projectId) {
        return;
      }

      setState(() {
        _project = project;
        _thread = thread;
        _messages = _ordered(_merge(const <Message>[], messages));
        _hasMoreOlder = messages.length >= _pageSize;
        _loading = false;
        _error = null;
      });
      _scrollToBottomSoon(jump: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _messageFor(error);
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _scrollController.offset > 80) {
      return;
    }
    if (_loadingOlder || !_hasMoreOlder || _thread == null) {
      return;
    }
    unawaited(_loadOlder());
  }

  Future<void> _loadOlder() async {
    final thread = _thread;
    if (thread == null) {
      return;
    }
    setState(() => _loadingOlder = true);
    final previousExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    try {
      final older = await ref
          .read(threadServiceProvider)
          .listMessages(thread.id, limit: _pageSize, offset: _messages.length);
      if (!mounted || thread.id != _thread?.id) {
        return;
      }
      setState(() {
        _messages = _ordered(_merge(_messages, older));
        _hasMoreOlder = older.length >= _pageSize;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        final nextExtent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(
          _scrollController.offset + nextExtent - previousExtent,
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  Future<void> _send() async {
    final thread = _thread;
    final auth = ref.read(authControllerProvider).asData?.value;
    final userId = auth?.user?.id;
    final body = _composerController.text.trim();
    if (thread == null || body.isEmpty || _sending) {
      return;
    }

    final optimistic = _optimisticMessage(
      threadId: thread.id,
      body: body,
      userId: userId,
    );
    _composerController.clear();
    setState(() {
      _sending = true;
      _messages = _ordered(_merge(_messages, [optimistic]));
    });
    _scrollToBottomSoon();

    try {
      final created = await ref
          .read(messageServiceProvider)
          .sendToThread(thread.id, body);
      if (!mounted || thread.id != _thread?.id) {
        return;
      }
      setState(() {
        _messages = _ordered(
          _merge(_dropOptimisticTwin(_messages, created), created),
        );
      });
      _scrollToBottomSoon();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimistic.id)
            .toList(growable: false);
        _sending = false;
      });
      _composerController.text = body;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _composerFocus.requestFocus();
      }
    }
  }

  void _scrollToBottomSoon({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (jump || !_didInitialScroll) {
        _scrollController.jumpTo(target);
      } else {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ),
        );
      }
      _didInitialScroll = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;

    if (_loading) {
      return Scaffold(
        backgroundColor: tokens.background,
        body: const SafeArea(
          child: Center(child: MaiaMarkWidget(animate: true)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: tokens.background,
        body: SafeArea(
          child: _ErrorState(
            message: _error!,
            onRetry: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              unawaited(_load());
            },
          ),
        ),
      );
    }

    final project = _project;
    if (project == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;
            final rightPanelVisible = desktop && _rightPanelOpen;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _ProjectHeader(
                        project: project,
                        rightPanelOpen: _rightPanelOpen,
                        showPanelToggle: desktop,
                        onBack: () => context.go('/'),
                        onTogglePanel: () {
                          setState(() => _rightPanelOpen = !_rightPanelOpen);
                        },
                      ),
                      Expanded(child: _buildMessageList(project)),
                      _Composer(
                        controller: _composerController,
                        focusNode: _composerFocus,
                        sending: _sending,
                        onSend: _send,
                      ),
                    ],
                  ),
                ),
                if (rightPanelVisible)
                  _RightPanel(
                    project: project,
                    onCollapse: () => setState(() => _rightPanelOpen = false),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageList(ProjectWithMembers project) {
    final tokens = context.maia;
    final auth = ref.watch(authControllerProvider).asData?.value;
    final currentUserId = auth?.user?.id;
    final messagesById = {for (final message in _messages) message.id: message};

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MaiaMarkWidget(size: 30, animate: true),
              const SizedBox(height: 14),
              Text(
                'No messages yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send the first project update to Maia.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.dim),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          if (_loadingOlder) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SpinnerWidget(size: 18)),
            );
          }
          if (_hasMoreOlder) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  'Scroll up for older messages',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: tokens.faint),
                ),
              ),
            );
          }
          return const SizedBox(height: 6);
        }

        final message = _messages[index - 1];
        if (!_messageTypes.contains(message.type)) {
          return const SizedBox.shrink();
        }
        return _MessageBubble(
          message: message,
          project: project,
          currentUserId: currentUserId,
          messagesById: messagesById,
        );
      },
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.rightPanelOpen,
    required this.showPanelToggle,
    required this.onBack,
    required this.onTogglePanel,
  });

  final ProjectWithMembers project;
  final bool rightPanelOpen;
  final bool showPanelToggle;
  final VoidCallback onBack;
  final VoidCallback onTogglePanel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tokens.backgroundRaised,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Projects',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          ProjectAvatarWidget(
            code: project.code,
            icon: project.icon,
            accent: project.accentColor,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${project.members.length} member${project.members.length == 1 ? '' : 's'}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: tokens.dim),
                ),
              ],
            ),
          ),
          if (showPanelToggle)
            IconButton(
              tooltip: rightPanelOpen ? 'Hide details' : 'Show details',
              onPressed: onTogglePanel,
              icon: Icon(
                rightPanelOpen
                    ? Icons.view_sidebar_rounded
                    : Icons.view_sidebar_outlined,
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.project,
    required this.currentUserId,
    required this.messagesById,
  });

  final Message message;
  final ProjectWithMembers project;
  final String? currentUserId;
  final Map<String, Message> messagesById;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final isUser = message.type == 'user_reply';
    final isMaia = !isUser;
    final isRelay = message.type == 'maia_relay';
    final isDigest = message.type == 'maia_digest';
    final isSummary = message.type == 'maia_summary';
    final isDanger = message.tone == 'danger';
    final body = (message.body ?? '').trim();
    if (body.isEmpty) {
      return const SizedBox.shrink();
    }

    final quote = _replyQuote();
    final bubbleColor = isUser
        ? tokens.accent
        : isDanger
        ? tokens.danger.withValues(alpha: tokens.isDark ? 0.18 : 0.10)
        : tokens.backgroundCard;
    final textColor = isUser ? tokens.accentInk : tokens.text;
    final borderColor = isDanger
        ? tokens.danger.withValues(alpha: 0.34)
        : isRelay
        ? tokens.accent.withValues(alpha: 0.28)
        : tokens.border;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMaia) ...[
            const MaiaMarkWidget(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (_eyebrow(context) case final eyebrow?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                      child: eyebrow,
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(isUser ? 18 : 14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (quote != null) ...[
                          _QuotePreview(quote: quote, inverted: isUser),
                          const SizedBox(height: 8),
                        ],
                        if (isDigest || isSummary)
                          _MessageCardMarkdown(body: body, color: textColor)
                        else
                          MarkdownBody(
                            data: body,
                            selectable: true,
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(
                                  Theme.of(context),
                                ).copyWith(
                                  p: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: textColor,
                                        height: 1.36,
                                      ),
                                  strong: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  code: TextStyle(
                                    color: textColor,
                                    backgroundColor: textColor.withValues(
                                      alpha: 0.10,
                                    ),
                                  ),
                                ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text(
                      DateFormat('h:mm a').format(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.faint,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            AvatarWidget(
              name: _memberName(currentUserId) ?? 'You',
              avatarUrl: _memberAvatar(currentUserId),
              size: 28,
            ),
          ],
        ],
      ),
    );
  }

  Widget? _eyebrow(BuildContext context) {
    final tokens = context.maia;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: tokens.accent,
      fontWeight: FontWeight.w800,
    );
    return switch (message.type) {
      'maia_ask' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MaiaMarkWidget(size: 10),
          const SizedBox(width: 4),
          Text('check-in', style: style),
        ],
      ),
      'maia_relay' => Text(_relayLabel(), style: style),
      'maia_summary' => Text('summary', style: style),
      'maia_digest' => Text('digest', style: style),
      _ =>
        message.tone == 'danger'
            ? Text(
                message.resolvedAt == null ? 'flagged' : 'resolved',
                style: style?.copyWith(color: tokens.danger),
              )
            : null,
    };
  }

  String _relayLabel() {
    final sender = _memberName(message.fromUserId);
    final isBroadcast =
        message.recipient?.kind == 'everyone' ||
        message.toAudience == 'everyone';
    if (isBroadcast) {
      return sender == null ? 'broadcast' : '$sender - broadcast';
    }
    return sender == null ? 'relay' : '$sender - via Maia';
  }

  _ReplyQuote? _replyQuote() {
    final parentId = message.repliesToMessageId;
    if (parentId == null ||
        (message.type != 'maia_relay' && message.type != 'user_reply')) {
      return null;
    }
    final preview = message.replyToPreview;
    final parent = messagesById[parentId];
    final snippet = preview?.bodySnippet ?? parent?.body;
    if (snippet == null || snippet.trim().isEmpty) {
      return null;
    }
    final fromUserId = preview?.fromUserId ?? parent?.fromUserId;
    final toUserId = preview?.toUserId ?? parent?.toUserId;
    final otherPartyId =
        fromUserId != null &&
            currentUserId != null &&
            fromUserId == currentUserId
        ? toUserId
        : fromUserId;
    return _ReplyQuote(
      author: _memberName(otherPartyId) ?? 'previous message',
      body: snippet,
    );
  }

  String? _memberName(String? userId) {
    if (userId == null) {
      return null;
    }
    for (final member in project.members) {
      if (member.userId == userId) {
        return member.user?.name;
      }
    }
    return null;
  }

  String? _memberAvatar(String? userId) {
    if (userId == null) {
      return null;
    }
    for (final member in project.members) {
      if (member.userId == userId) {
        return member.user?.avatarUrl;
      }
    }
    return null;
  }
}

class _MessageCardMarkdown extends StatelessWidget {
  const _MessageCardMarkdown({required this.body, required this.color});

  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: body,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: color, height: 1.38),
        h1: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
        h2: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
        listBullet: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}

class _ReplyQuote {
  const _ReplyQuote({required this.author, required this.body});

  final String author;
  final String body;
}

class _QuotePreview extends StatelessWidget {
  const _QuotePreview({required this.quote, required this.inverted});

  final _ReplyQuote quote;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final color = inverted ? tokens.accentInk : tokens.dim;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.5), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to ${quote.author}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            quote.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.82),
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: tokens.backgroundRaised,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              style: TextStyle(color: tokens.text),
              decoration: InputDecoration(
                hintText: 'Message Maia',
                hintStyle: TextStyle(color: tokens.faint),
                filled: true,
                fillColor: tokens.backgroundCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: tokens.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: tokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: tokens.accent),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: sending ? null : onSend,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
              backgroundColor: tokens.accent,
              foregroundColor: tokens.accentInk,
            ),
            child: sending
                ? const SpinnerWidget(size: 18)
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.project, required this.onCollapse});

  final ProjectWithMembers project;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: tokens.backgroundRaised,
        border: Border(left: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Project',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: tokens.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Collapse',
                  onPressed: onCollapse,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Text(
              project.description.isEmpty
                  ? 'Context panel details will be added in a later pass.'
                  : project.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.dim, height: 1.35),
            ),
          ),
          Divider(height: 1, color: tokens.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              'Members',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              itemCount: project.members.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final member = project.members[index];
                final name = member.user?.name ?? 'Member';
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: AvatarWidget(
                    name: name,
                    avatarUrl: member.user?.avatarUrl,
                    size: 30,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.text),
                  ),
                  subtitle: Text(
                    member.role,
                    style: TextStyle(color: tokens.faint),
                  ),
                );
              },
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: tokens.danger, size: 34),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.danger),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class MaiaMarkWidget extends StatefulWidget {
  const MaiaMarkWidget({
    super.key,
    this.size = 32,
    this.color,
    this.animate = false,
  });

  final double size;
  final Color? color;
  final bool animate;

  @override
  State<MaiaMarkWidget> createState() => _MaiaMarkWidgetState();
}

class _MaiaMarkWidgetState extends State<MaiaMarkWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant MaiaMarkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.maia.accent;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = widget.animate ? 0.85 + (_controller.value * 0.18) : 1.0;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _MaiaMarkPainter(color: color, pulse: pulse),
        );
      },
    );
  }
}

class _MaiaMarkPainter extends CustomPainter {
  const _MaiaMarkPainter({required this.color, required this.pulse});

  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..color = color.withValues(alpha: 0.20);
    final middle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..color = color.withValues(alpha: 0.45);
    final dot = Paint()..color = color;
    canvas
      ..drawCircle(center, size.width * 0.46 * pulse, outer)
      ..drawCircle(center, size.width * 0.32 * pulse, middle)
      ..drawCircle(center, size.width * 0.15, dot);
  }

  @override
  bool shouldRepaint(covariant _MaiaMarkPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pulse != pulse;
  }
}

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    required this.name,
    super.key,
    this.avatarUrl,
    this.size = 32,
    this.initialsChars = 1,
    this.color,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final int initialsChars;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallbackColor = color ?? _avatarColor(name);
    final url = avatarUrl;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: url == null || url.isEmpty
            ? fallbackColor.withValues(alpha: 0.20)
            : Colors.transparent,
        alignment: Alignment.center,
        child: url == null || url.isEmpty
            ? Text(
                _initials(name, initialsChars),
                style: TextStyle(
                  color: fallbackColor,
                  fontSize: (size * 0.4).roundToDouble(),
                  fontWeight: FontWeight.w800,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) => Text(
                  _initials(name, initialsChars),
                  style: TextStyle(
                    color: fallbackColor,
                    fontSize: (size * 0.4).roundToDouble(),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}

class SpinnerWidget extends StatelessWidget {
  const SpinnerWidget({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.maia.accent,
      ),
    );
  }
}

class SkeletonWidget extends StatefulWidget {
  const SkeletonWidget({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonWidget> createState() => _SkeletonWidgetState();
}

class _SkeletonWidgetState extends State<SkeletonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.92).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: tokens.border.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

Message _optimisticMessage({
  required String threadId,
  required String body,
  required String? userId,
}) {
  final now = DateTime.now();
  return Message(
    id: 'temp-${now.microsecondsSinceEpoch}',
    threadId: threadId,
    type: 'user_reply',
    body: body,
    tone: null,
    fromUserId: userId,
    toUserId: null,
    toAudience: null,
    recipient: null,
    repliesToMessageId: null,
    replyToPreview: null,
    originalText: null,
    extra: null,
    promptVersionId: null,
    createdAt: now,
    resolvedAt: null,
  );
}

List<Message> _merge(List<Message> current, List<Message> incoming) {
  final byId = <String, Message>{
    for (final message in current) message.id: message,
  };
  for (final message in incoming) {
    byId[message.id] = message;
  }
  return byId.values.toList(growable: false);
}

List<Message> _dropOptimisticTwin(
  List<Message> current,
  List<Message> incoming,
) {
  final incomingReplies = incoming
      .where((message) => message.type == 'user_reply')
      .map(
        (message) =>
            '${message.threadId}|${message.fromUserId}|${message.body}',
      )
      .toSet();
  return current
      .where((message) {
        if (!message.id.startsWith('temp-')) {
          return true;
        }
        return !incomingReplies.contains(
          '${message.threadId}|${message.fromUserId}|${message.body}',
        );
      })
      .toList(growable: false);
}

List<Message> _ordered(List<Message> messages) {
  final sorted = [...messages];
  sorted.sort((a, b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    if (byTime != 0) {
      return byTime;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
}

String _messageFor(Object error) {
  if (error is ApiException && error.message.isNotEmpty) {
    return error.message;
  }
  return 'Failed to load project chat.';
}

const _avatarColors = <Color>[
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

Color _avatarColor(String name) {
  var hash = 0;
  for (final codeUnit in name.codeUnits) {
    hash = codeUnit + ((hash << 5) - hash);
  }
  return _avatarColors[hash.abs() % _avatarColors.length];
}

String _initials(String name, int chars) {
  return name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part.characters.first)
      .join()
      .toUpperCase()
      .characters
      .take(chars)
      .toString();
}
