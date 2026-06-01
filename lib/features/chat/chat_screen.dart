import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/network.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../core/theme/maia_theme_tokens.dart';
import '../../models/models.dart';
import '../projects/project_avatar_widget.dart';
import '../projects/project_context_panel.dart';
import '../projects/project_settings_sheet.dart';

const _pageSize = 100;
const _reconcileWindow = 40;
const _activePollInterval = Duration(seconds: 3);
const _idlePollInterval = Duration(seconds: 10);
const _messageTypes = <String>{
  'maia_ask',
  'user_reply',
  'maia_note',
  'maia_relay',
  'maia_summary',
  'maia_digest',
};

class MessageAttachmentRef {
  const MessageAttachmentRef({
    required this.assetId,
    required this.ref,
    required this.kind,
    required this.status,
    required this.mimeType,
  });

  final String assetId;
  final String ref;
  final String kind;
  final String status;
  final String? mimeType;
}

bool isRelayMediaConfirmMessage(Message message) {
  return message.type == 'maia_note' &&
      message.extra?['kind']?.toString() == 'relay_media_confirm';
}

List<MessageAttachmentRef> messageAttachmentsOf(Message message) {
  final raw = message.extra?['attachments'];
  if (raw is! List) {
    return const <MessageAttachmentRef>[];
  }
  final attachments = <MessageAttachmentRef>[];
  for (final value in raw) {
    if (value is! Map) {
      continue;
    }
    final assetId = value['asset_id']?.toString();
    if (assetId == null || assetId.isEmpty) {
      continue;
    }
    attachments.add(
      MessageAttachmentRef(
        assetId: assetId,
        ref: value['ref']?.toString() ?? 'media',
        kind: value['kind']?.toString() ?? 'image',
        status: value['status']?.toString() ?? 'pending',
        mimeType: value['mime_type']?.toString(),
      ),
    );
  }
  return attachments;
}

bool shouldRenderChatMessage(Message message) {
  final body = (message.body ?? '').trim();
  return body.isNotEmpty || messageAttachmentsOf(message).isNotEmpty;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();

  ProjectWithMembers? _project;
  Thread? _thread;
  List<Message> _messages = const <Message>[];
  List<MemberStatus> _teamStatus = const <MemberStatus>[];
  List<Message> _memberTimeline = const <Message>[];
  String? _activeMemberId;
  MemberStatus? _relayTarget;
  String? _error;
  bool _loading = true;
  bool _isSending = false;
  bool _isMaiaThinking = false;
  bool _timelineLoading = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = false;
  bool _rightPanelOpen = true;
  bool _didInitialScroll = false;
  bool _broadcastMode = false;
  bool _triggerCheckinBusy = false;
  bool _triggerSummaryBusy = false;
  bool _mentionOpen = false;
  InferenceStatus _inferenceStatus = const InferenceStatus(active: false);
  DateTime? _lastPollAt;
  String? _workspaceRole;
  ({String code, String message})? _pollError;
  int _projectUpdateTick = 0;
  String _mentionQuery = '';
  int _mentionStart = -1;
  int _mentionIndex = 0;
  final Set<String> _mentionedUserIds = <String>{};
  Timer? _pollTimer;
  bool _pollInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pollThread(immediate: true));
      unawaited(_refreshProject());
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _stopPolling();
      setState(() {
        _project = null;
        _thread = null;
        _messages = const <Message>[];
        _teamStatus = const <MemberStatus>[];
        _memberTimeline = const <Message>[];
        _activeMemberId = null;
        _relayTarget = null;
        _error = null;
        _loading = true;
        _isSending = false;
        _isMaiaThinking = false;
        _timelineLoading = false;
        _loadingOlder = false;
        _hasMoreOlder = false;
        _didInitialScroll = false;
        _broadcastMode = false;
        _triggerCheckinBusy = false;
        _triggerSummaryBusy = false;
        _mentionOpen = false;
        _inferenceStatus = const InferenceStatus(active: false);
        _lastPollAt = null;
        _workspaceRole = null;
        _pollError = null;
        _projectUpdateTick = 0;
        _mentionQuery = '';
        _mentionStart = -1;
        _mentionIndex = 0;
        _mentionedUserIds.clear();
      });
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
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
        ref.read(projectServiceProvider).teamStatus(projectId),
      ]);
      if (!mounted || projectId != widget.projectId) {
        return;
      }

      final project = results[0] as ProjectWithMembers?;
      final thread = results[1] as Thread?;
      final teamStatus = results[2] as List<MemberStatus>;
      if (project == null || thread == null) {
        throw const ApiException(null, 'Project chat could not be loaded.');
      }
      final workspaceRole = await _loadWorkspaceRole(project.tenantId);

      final messages = await ref
          .read(threadServiceProvider)
          .listMessages(thread.id, limit: _pageSize);
      if (!mounted || projectId != widget.projectId) {
        return;
      }

      setState(() {
        _project = project;
        _thread = thread;
        _teamStatus = teamStatus;
        _messages = _ordered(_merge(const <Message>[], messages));
        _hasMoreOlder = messages.length >= _pageSize;
        _workspaceRole = workspaceRole;
        _loading = false;
        _error = null;
      });
      _startPolling(thread.id, immediate: true);
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

  Future<String?> _loadWorkspaceRole(String tenantId) async {
    final auth = ref.read(authControllerProvider).asData?.value;
    final userId = auth?.user?.id;
    if (userId == null || tenantId.isEmpty) {
      return null;
    }
    try {
      final members = await ref.read(userServiceProvider).tenantMembers();
      for (final member in members) {
        if (member.tenantId == tenantId && member.userId == userId) {
          return member.role.toLowerCase();
        }
      }
    } catch (_) {
      // The backend still enforces trigger permissions; missing role data only
      // affects whether Flutter can optimistically show the Trigger menu.
    }
    return null;
  }

  void _startPolling(String threadId, {bool immediate = false}) {
    _stopPolling();
    if (immediate) {
      unawaited(_pollThread(immediate: true));
    }
    _scheduleNextPoll(threadId);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInFlight = false;
  }

  void _scheduleNextPoll(String threadId) {
    _pollTimer?.cancel();
    final interval = chatPollInterval(
      isSending: _isSending,
      inferenceActive: _inferenceStatus.active,
    );
    _pollTimer = Timer(interval, () {
      if (!mounted || threadId != _thread?.id) {
        return;
      }
      unawaited(_pollThread());
    });
  }

  Future<void> _pollThread({bool immediate = false}) async {
    final thread = _thread;
    if (thread == null || _pollInFlight) {
      return;
    }
    _pollInFlight = true;
    try {
      final results = await Future.wait<Object?>([
        ref
            .read(threadServiceProvider)
            .listMessages(thread.id, limit: _reconcileWindow),
        ref.read(threadServiceProvider).getInferenceStatus(thread.id),
      ]);
      if (!mounted || thread.id != _thread?.id) {
        return;
      }
      final latest = results[0] as List<Message>;
      final status = results[1] as InferenceStatus;
      setState(() {
        _messages = _ordered(
          _merge(_dropOptimisticTwin(_messages, latest), latest),
        );
        _inferenceStatus = status;
        if (!status.active) {
          _isSending = false;
        }
        _isMaiaThinking = _isSending || status.active;
        _lastPollAt = DateTime.now();
        _pollError = null;
      });
      if (latest.isNotEmpty || immediate) {
        _scrollToBottomSoon();
      }
      if (!status.active) {
        _composerFocus.requestFocus();
      }
    } catch (error) {
      if (mounted && thread.id == _thread?.id) {
        setState(() {
          _lastPollAt = DateTime.now();
          _pollError = (code: 'poll_failed', message: _messageFor(error));
        });
      }
    } finally {
      _pollInFlight = false;
      if (mounted && thread.id == _thread?.id) {
        _scheduleNextPoll(thread.id);
      }
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
    if (thread == null || body.isEmpty || _isSending) {
      return;
    }

    if (_broadcastMode) {
      await _confirmBroadcast(body);
      return;
    }

    final optimistic = _optimisticMessage(
      threadId: thread.id,
      body: body,
      userId: userId,
    );
    final mentionUserIds = _canonicalMentionUserIds(body);
    _composerController.clear();
    setState(() {
      _isSending = true;
      _isMaiaThinking = true;
      _mentionOpen = false;
      _mentionedUserIds.clear();
      _pollError = null;
      _messages = _ordered(_merge(_messages, [optimistic]));
    });
    _scrollToBottomSoon();

    try {
      final result = await ref
          .read(chatTransportServiceProvider)
          .sendMessage(thread.id, body, mentionUserIds: mentionUserIds);
      if (!mounted || thread.id != _thread?.id) {
        return;
      }
      if (result.pending) {
        setState(() {
          _isSending = true;
          _isMaiaThinking = true;
          _inferenceStatus = InferenceStatus(
            active: true,
            sessionId: result.sessionId,
          );
        });
        await _pollThread(immediate: true);
        return;
      }
      final maiaResponse = result.maiaResponse;
      setState(() {
        if (maiaResponse != null) {
          _messages = _ordered(
            _merge(_dropOptimisticTwin(_messages, [maiaResponse]), [
              maiaResponse,
            ]),
          );
        }
        _isSending = false;
        _isMaiaThinking = false;
        _inferenceStatus = InferenceStatus(
          active: false,
          sessionId: result.sessionId,
        );
      });
      unawaited(_pollThread(immediate: true));
      _composerFocus.requestFocus();
      _scrollToBottomSoon();
    } catch (error) {
      if (!mounted || thread.id != _thread?.id) {
        return;
      }
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimistic.id)
            .toList(growable: false);
        _isSending = false;
        _isMaiaThinking = _inferenceStatus.active;
        _pollError = (code: 'send_failed', message: _messageFor(error));
      });
      _composerController.text = body;
      _composerFocus.requestFocus();
      _scrollToBottomSoon();
    }
  }

  Future<void> _sendConfirmationReply(String body) async {
    final thread = _thread;
    final auth = ref.read(authControllerProvider).asData?.value;
    final userId = auth?.user?.id;
    final normalized = body.trim();
    if (thread == null || normalized.isEmpty || _isSending) {
      return;
    }

    final optimistic = _optimisticMessage(
      threadId: thread.id,
      body: normalized,
      userId: userId,
    );
    setState(() {
      _isSending = true;
      _isMaiaThinking = true;
      _pollError = null;
      _messages = _ordered(_merge(_messages, [optimistic]));
    });
    _scrollToBottomSoon();

    try {
      final result = await ref
          .read(chatTransportServiceProvider)
          .sendMessage(thread.id, normalized);
      if (!mounted || thread.id != _thread?.id) {
        return;
      }
      if (result.pending) {
        setState(() {
          _inferenceStatus = InferenceStatus(
            active: true,
            sessionId: result.sessionId,
          );
        });
        await _pollThread(immediate: true);
        return;
      }
      final maiaResponse = result.maiaResponse;
      setState(() {
        if (maiaResponse != null) {
          _messages = _ordered(
            _merge(_dropOptimisticTwin(_messages, [maiaResponse]), [
              maiaResponse,
            ]),
          );
        }
        _isSending = false;
        _isMaiaThinking = false;
        _inferenceStatus = InferenceStatus(
          active: false,
          sessionId: result.sessionId,
        );
      });
      unawaited(_pollThread(immediate: true));
      _scrollToBottomSoon();
    } catch (error) {
      if (!mounted || thread.id != _thread?.id) {
        return;
      }
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimistic.id)
            .toList(growable: false);
        _isSending = false;
        _isMaiaThinking = _inferenceStatus.active;
        _pollError = (code: 'send_failed', message: _messageFor(error));
      });
      _scrollToBottomSoon();
    }
  }

  Future<void> _confirmBroadcast(String body) async {
    final project = _project;
    if (project == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isSending,
      builder: (context) =>
          _BroadcastConfirmDialog(project: project, preview: body),
    );
    if (confirmed != true || !mounted) {
      _composerFocus.requestFocus();
      return;
    }

    setState(() => _isSending = true);
    try {
      final created = await ref
          .read(messageServiceProvider)
          .broadcast(projectId: project.id, body: body);
      if (!mounted || project.id != widget.projectId) {
        return;
      }
      _composerController.clear();
      setState(() {
        _broadcastMode = false;
        _mentionOpen = false;
        _mentionedUserIds.clear();
        _messages = _ordered(_merge(_messages, created));
      });
      _scrollToBottomSoon();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _composerFocus.requestFocus();
      }
    }
  }

  Future<void> _triggerCheckin() async {
    final project = _project;
    if (project == null || _triggerCheckinBusy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_triggerCheckinBusy,
      builder: (context) => _TriggerConfirmDialog(
        title: 'Trigger on-demand check-in?',
        body:
            'Maia will ask check-in-enabled project members for an update now.',
        actionLabel: 'Trigger check-in',
      ),
    );
    if (confirmed != true || !mounted) {
      _composerFocus.requestFocus();
      return;
    }

    setState(() => _triggerCheckinBusy = true);
    try {
      await ref.read(schedulerServiceProvider).triggerCheckin(project.id);
      if (!mounted || project.id != widget.projectId) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('On-demand check-in started.')),
      );
      unawaited(_pollThread(immediate: true));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_schedulerMessageFor(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _triggerCheckinBusy = false);
        _composerFocus.requestFocus();
      }
    }
  }

  Future<void> _triggerTeamSummary() async {
    final project = _project;
    if (project == null || _triggerSummaryBusy) {
      return;
    }
    setState(() => _triggerSummaryBusy = true);
    try {
      await ref.read(schedulerServiceProvider).triggerTeamSummary(project.id);
      if (!mounted || project.id != widget.projectId) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team summary generation started.')),
      );
      unawaited(_pollThread(immediate: true));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_schedulerMessageFor(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _triggerSummaryBusy = false);
        _composerFocus.requestFocus();
      }
    }
  }

  Future<void> _sendRelay({
    required String? targetUserId,
    required String body,
    String? repliesToMessageId,
  }) async {
    final project = _project;
    if (project == null || body.trim().isEmpty || _isSending) {
      return;
    }
    setState(() => _isSending = true);
    try {
      final created = await ref
          .read(messageServiceProvider)
          .relay(
            projectId: project.id,
            targetUserId: targetUserId,
            body: body.trim(),
            repliesToMessageId: repliesToMessageId,
          );
      if (!mounted || project.id != widget.projectId) {
        return;
      }
      setState(() {
        _messages = _ordered(_merge(_messages, created));
      });
      await _refreshTeamStatus();
      if (targetUserId != null && _activeMemberId == targetUserId) {
        await _loadMemberTimeline(targetUserId);
      }
      _scrollToBottomSoon();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _refreshTeamStatus() async {
    final projectId = widget.projectId;
    if (projectId.isEmpty) {
      return;
    }
    try {
      final status = await ref
          .read(projectServiceProvider)
          .teamStatus(projectId);
      if (mounted && projectId == widget.projectId) {
        setState(() => _teamStatus = status);
      }
    } catch (_) {}
  }

  Future<void> _refreshProject() async {
    final projectId = widget.projectId;
    final project = await ref.read(projectServiceProvider).get(projectId);
    final teamStatus = await ref
        .read(projectServiceProvider)
        .teamStatus(projectId);
    if (!mounted || projectId != widget.projectId || project == null) {
      return;
    }
    setState(() {
      _project = project;
      _teamStatus = teamStatus;
    });
  }

  Future<void> _loadMemberTimeline(String userId) async {
    final project = _project;
    if (project == null) {
      return;
    }
    setState(() {
      _timelineLoading = true;
      _activeMemberId = userId;
    });
    try {
      final timeline = await ref
          .read(projectServiceProvider)
          .memberTimeline(project.id, userId);
      if (mounted &&
          project.id == widget.projectId &&
          _activeMemberId == userId) {
        setState(() => _memberTimeline = _ordered(timeline));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    } finally {
      if (mounted && _activeMemberId == userId) {
        setState(() => _timelineLoading = false);
      }
    }
  }

  Future<void> _toggleResolved(String messageId, bool nextResolved) async {
    final previous = _messages;
    final now = DateTime.now().toUtc();
    setState(() {
      _messages = _messages
          .map(
            (message) => message.id == messageId
                ? message.copyWith(resolvedAt: nextResolved ? now : null)
                : message,
          )
          .toList(growable: false);
      _memberTimeline = _memberTimeline
          .map(
            (message) => message.id == messageId
                ? message.copyWith(resolvedAt: nextResolved ? now : null)
                : message,
          )
          .toList(growable: false);
    });
    try {
      final updated = nextResolved
          ? await ref.read(messageServiceProvider).resolve(messageId)
          : await ref.read(messageServiceProvider).unresolve(messageId);
      if (!mounted || updated == null) {
        return;
      }
      setState(() {
        _messages = _ordered(_merge(_messages, [updated]));
        _memberTimeline = _ordered(_merge(_memberTimeline, [updated]));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _messages = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
  }

  void _handleComposerChanged(String value) {
    final selection = _composerController.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > value.length) {
      setState(() => _mentionOpen = false);
      return;
    }
    final before = value.substring(0, cursor);
    final match = RegExp(r'(^|\s)@([A-Za-z0-9._ -]*)$').firstMatch(before);
    if (match == null) {
      setState(() => _mentionOpen = false);
      return;
    }
    setState(() {
      _mentionStart = match.start + match.group(1)!.length;
      _mentionQuery = match.group(2)!.trim().toLowerCase();
      _mentionIndex = 0;
      _mentionOpen = _mentionCandidates.isNotEmpty;
    });
  }

  void _insertMention(ProjectMember member) {
    final user = member.user;
    final name = user?.name.trim() ?? 'Member';
    final text = _composerController.text;
    final selection = _composerController.selection;
    final end = selection.baseOffset < 0 ? text.length : selection.baseOffset;
    final start = _mentionStart.clamp(0, end);
    final next = '${text.substring(0, start)}@$name ${text.substring(end)}';
    final cursor = start + name.length + 2;
    _composerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    setState(() {
      _mentionedUserIds.add(member.userId);
      _mentionOpen = false;
      _mentionQuery = '';
    });
    _composerFocus.requestFocus();
  }

  List<String> _canonicalMentionUserIds(String body) {
    final membersById = <String, ProjectMember>{
      for (final member in _project?.members ?? const <ProjectMember>[])
        member.userId: member,
    };
    return _mentionedUserIds
        .where((id) {
          final name = membersById[id]?.user?.name.trim();
          return name != null && name.isNotEmpty && body.contains('@$name');
        })
        .toList(growable: false);
  }

  List<ProjectMember> get _mentionCandidates {
    final query = _mentionQuery;
    return (_project?.members ?? const <ProjectMember>[])
        .where((member) {
          final name = member.user?.name.toLowerCase() ?? '';
          final title = member.user?.title.toLowerCase() ?? '';
          return query.isEmpty || name.contains(query) || title.contains(query);
        })
        .take(6)
        .toList(growable: false);
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
    final auth = ref.watch(authControllerProvider).asData?.value;
    final currentUser = auth?.user;
    final currentUserId = currentUser?.id;
    final isProjectAdmin = project.members.any(
      (member) =>
          member.userId == currentUserId &&
          member.role.toLowerCase() == 'admin',
    );
    final isWorkspaceAdmin =
        _workspaceRole == 'admin' || _workspaceRole == 'super_admin';
    final isAdmin = currentUser?.isSuperAdmin == true || isProjectAdmin;
    final canDeleteProject =
        currentUser?.isSuperAdmin == true || isProjectAdmin || isWorkspaceAdmin;
    final canTrigger =
        currentUser?.isSuperAdmin == true || isProjectAdmin || isWorkspaceAdmin;

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
                        canOpenSettings: isAdmin || canDeleteProject,
                        onBack: () => context.go('/'),
                        onTogglePanel: () {
                          setState(() => _rightPanelOpen = !_rightPanelOpen);
                        },
                        onSettings: () => _showProjectSettings(
                          project,
                          isAdmin,
                          canDeleteProject,
                        ),
                      ),
                      Expanded(
                        child: _activeMemberId == null
                            ? _buildMessageList(project)
                            : _MemberTimelineView(
                                project: project,
                                memberId: _activeMemberId!,
                                currentUserId: currentUserId,
                                messages: _memberTimeline,
                                loading: _timelineLoading,
                                sending: _isSending,
                                onBack: () => setState(() {
                                  _activeMemberId = null;
                                  _memberTimeline = const <Message>[];
                                }),
                                onRelay: (body) => _sendRelay(
                                  targetUserId: _activeMemberId!,
                                  body: body,
                                ),
                                onToggleResolved: _toggleResolved,
                              ),
                      ),
                      if (_activeMemberId == null)
                        _Composer(
                          controller: _composerController,
                          focusNode: _composerFocus,
                          sending: _isSending,
                          broadcastMode: _broadcastMode,
                          mentionOpen: _mentionOpen,
                          mentionIndex: _mentionIndex,
                          mentionCandidates: _mentionCandidates,
                          canTrigger: canTrigger,
                          triggerCheckinBusy: _triggerCheckinBusy,
                          triggerSummaryBusy: _triggerSummaryBusy,
                          onChanged: _handleComposerChanged,
                          onPickMention: _insertMention,
                          onToggleBroadcast: () {
                            setState(() {
                              _broadcastMode = !_broadcastMode;
                              if (_broadcastMode) {
                                _mentionOpen = false;
                              }
                            });
                          },
                          onTriggerCheckin: _triggerCheckin,
                          onTriggerTeamSummary: _triggerTeamSummary,
                          onSend: _send,
                        ),
                    ],
                  ),
                ),
                if (rightPanelVisible)
                  _RightPanel(
                    project: project,
                    teamStatus: _teamStatus,
                    currentUserId: currentUserId,
                    activeMemberId: _activeMemberId,
                    isAdmin: isAdmin,
                    refreshTick: _projectUpdateTick,
                    onCollapse: () => setState(() => _rightPanelOpen = false),
                    onSelectMember: (status) {
                      if (status.userId == currentUserId) {
                        setState(() {
                          _activeMemberId = null;
                          _relayTarget = null;
                        });
                        return;
                      }
                      if (isAdmin) {
                        unawaited(_loadMemberTimeline(status.userId));
                      } else {
                        setState(() => _relayTarget = status);
                      }
                    },
                  ),
              ],
            );
          },
        ),
      ),
      bottomSheet: _relayTarget == null
          ? null
          : _RelaySheet(
              target: _relayTarget!,
              onClose: () => setState(() => _relayTarget = null),
              onSubmit: (body) async {
                final target = _relayTarget;
                if (target == null) {
                  return;
                }
                await _sendRelay(targetUserId: target.userId, body: body);
                if (mounted) {
                  setState(() => _relayTarget = null);
                }
              },
            ),
    );
  }

  Widget _buildMessageList(ProjectWithMembers project) {
    final tokens = context.maia;
    final auth = ref.watch(authControllerProvider).asData?.value;
    final currentUserId = auth?.user?.id;
    final messagesById = {for (final message in _messages) message.id: message};

    if (_messages.isEmpty && !_isMaiaThinking && _pollError == null) {
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

    final statusCount = _pollStatusCount;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      itemCount: _messages.length + 1 + statusCount,
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

        final messageIndex = index - 1;
        if (messageIndex >= _messages.length) {
          return _buildStreamStatus(messageIndex - _messages.length);
        }

        final message = _messages[messageIndex];
        if (!_messageTypes.contains(message.type)) {
          return const SizedBox.shrink();
        }
        return _MessageBubble(
          message: message,
          project: project,
          currentUserId: currentUserId,
          messagesById: messagesById,
          myThreadId: _thread?.id,
          onToggleResolved: _toggleResolved,
          onConfirmMediaRelay: _sendConfirmationReply,
          onRelayReply: (message, body) => _sendRelay(
            targetUserId: message.recipient?.kind == 'everyone'
                ? null
                : message.fromUserId,
            body: body,
            repliesToMessageId: message.id,
          ),
        );
      },
    );
  }

  int get _pollStatusCount {
    if (_pollError != null) {
      return 1;
    }
    if (_isMaiaThinking) {
      return 1;
    }
    return 0;
  }

  Widget _buildStreamStatus(int statusIndex) {
    if (_pollError != null) {
      return _StreamErrorBanner(
        error: _pollError!,
        onDismiss: () => setState(() => _pollError = null),
      );
    }
    final hasPolled = _lastPollAt != null;
    return _ProgressPill(label: hasPolled ? 'Thinking...' : 'Thinking...');
  }

  Future<void> _showProjectSettings(
    ProjectWithMembers project,
    bool isAdmin,
    bool canDeleteProject,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProjectSettingsSheet(
        project: project,
        isCurrentUserAdmin: isAdmin,
        canDeleteProject: canDeleteProject,
        onUpdated: _refreshProject,
        onDeleted: () {
          Navigator.pop(context);
          this.context.go('/');
        },
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: tokens.backgroundRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpinnerWidget(size: 12),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.dim,
                fontFeatures: const [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamErrorBanner extends StatelessWidget {
  const _StreamErrorBanner({required this.error, required this.onDismiss});

  final ({String code, String message}) error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        constraints: const BoxConstraints(maxWidth: 680),
        decoration: BoxDecoration(
          color: tokens.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.code.replaceAll('_', ' ').toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text),
              ),
            ),
            TextButton(onPressed: onDismiss, child: const Text('ok')),
          ],
        ),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.rightPanelOpen,
    required this.showPanelToggle,
    required this.canOpenSettings,
    required this.onBack,
    required this.onTogglePanel,
    required this.onSettings,
  });

  final ProjectWithMembers project;
  final bool rightPanelOpen;
  final bool showPanelToggle;
  final bool canOpenSettings;
  final VoidCallback onBack;
  final VoidCallback onTogglePanel;
  final VoidCallback onSettings;

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
          if (canOpenSettings)
            IconButton(
              tooltip: 'Project settings',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
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
    required this.onToggleResolved,
    required this.onConfirmMediaRelay,
    required this.myThreadId,
    this.forceExpandedRelay = false,
    this.onRelayReply,
  });

  final Message message;
  final ProjectWithMembers project;
  final String? currentUserId;
  final Map<String, Message> messagesById;
  final String? myThreadId;
  final Future<void> Function(String messageId, bool nextResolved)
  onToggleResolved;
  final Future<void> Function(String body) onConfirmMediaRelay;
  final bool forceExpandedRelay;
  final Future<void> Function(Message message, String body)? onRelayReply;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final extra = message.extra;
    if (isRelayMediaConfirmMessage(message)) {
      return _RelayMediaConfirmBubble(
        message: message,
        onConfirm: onConfirmMediaRelay,
      );
    }
    if (message.type == 'maia_note') {
      final kind = extra?['kind']?.toString();
      if (kind == 'relay_sent' || kind == 'broadcast_sent') {
        return _RelayAckPill(message: message, project: project);
      }
    }
    if (message.type == 'maia_summary') {
      return _SummaryBubble(
        message: message,
        currentUserId: currentUserId,
        messagesById: messagesById,
        onToggleResolved: onToggleResolved,
      );
    }
    final isUser = message.type == 'user_reply';
    final isMaia = !isUser;
    final isRelay = message.type == 'maia_relay';
    final isDigest = message.type == 'maia_digest';
    final isDanger = message.tone == 'danger';
    final body = (message.body ?? '').trim();
    final attachments = messageAttachmentsOf(message);
    if (body.isEmpty && attachments.isEmpty) {
      return const SizedBox.shrink();
    }
    final isRecipientRelay =
        isRelay && currentUserId != null && message.fromUserId != currentUserId;
    if (isRecipientRelay && !forceExpandedRelay) {
      return _InboundRelayPill(
        message: message,
        project: project,
        currentUserId: currentUserId,
        messagesById: messagesById,
        onRelayReply: onRelayReply,
      );
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
                        if (body.isNotEmpty && isDigest)
                          _MessageCardMarkdown(body: body, color: textColor)
                        else if (body.isNotEmpty)
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
                        if (attachments.isNotEmpty) ...[
                          if (body.isNotEmpty) const SizedBox(height: 8),
                          _AttachmentGrid(attachments: attachments),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDanger && message.threadId == myThreadId) ...[
                          _ResolveButton(
                            resolved: message.resolvedAt != null,
                            onPressed: () => onToggleResolved(
                              message.id,
                              message.resolvedAt == null,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          DateFormat('h:mm a').format(message.createdAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: tokens.faint,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
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

class _RelayMediaConfirmBubble extends StatefulWidget {
  const _RelayMediaConfirmBubble({
    required this.message,
    required this.onConfirm,
  });

  final Message message;
  final Future<void> Function(String body) onConfirm;

  @override
  State<_RelayMediaConfirmBubble> createState() =>
      _RelayMediaConfirmBubbleState();
}

class _RelayMediaConfirmBubbleState extends State<_RelayMediaConfirmBubble> {
  bool _busy = false;

  Future<void> _submit(String body) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onConfirm(body);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final body = (widget.message.body ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaiaMarkWidget(size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.34),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forward_to_inbox_rounded,
                          size: 16,
                          color: tokens.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Confirm media relay',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: tokens.accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: body,
                        selectable: true,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.text, height: 1.36),
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _submit('yes send it'),
                          icon: _busy
                              ? const SpinnerWidget(size: 14)
                              : const Icon(Icons.check_rounded),
                          label: const Text('Send it'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _submit('no'),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Not now'),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('h:mm a').format(widget.message.createdAt),
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
          ),
        ],
      ),
    );
  }
}

class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({required this.attachments});

  final List<MessageAttachmentRef> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final attachment in attachments)
          _AttachmentTile(
            key: ValueKey(attachment.assetId),
            attachment: attachment,
          ),
      ],
    );
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({required this.attachment, super.key});

  final MessageAttachmentRef attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.maia;
    return FutureBuilder<MediaDownloadUrl?>(
      future: ref.read(mediaServiceProvider).downloadUrl(attachment.assetId),
      builder: (context, snapshot) {
        final signed = snapshot.data;
        final url = signed?.thumbUrl ?? signed?.url;
        final status = signed?.status.isNotEmpty == true
            ? signed!.status
            : attachment.status;
        final isImage = (signed?.kind ?? attachment.kind) == 'image';
        return InkWell(
          onTap: signed?.url == null
              ? null
              : () => _openAttachment(context, signed!.url, isImage: isImage),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 112,
            height: 112,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tokens.backgroundRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null && isImage)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _AttachmentPlaceholder(
                          label: 'unavailable',
                          icon: Icons.broken_image_outlined,
                          color: tokens.faint,
                        ),
                  )
                else
                  _AttachmentPlaceholder(
                    label: snapshot.hasError
                        ? 'unavailable'
                        : snapshot.connectionState == ConnectionState.done
                        ? attachment.kind
                        : '...',
                    icon: isImage
                        ? Icons.image_outlined
                        : Icons.play_circle_outline_rounded,
                    color: tokens.faint,
                  ),
                if (status != 'ready')
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _AttachmentStatusBadge(status: status),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    String url, {
    required bool isImage,
  }) async {
    if (!isImage) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.86),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentStatusBadge extends StatelessWidget {
  const _AttachmentStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final failed = status == 'failed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: failed ? tokens.danger : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        failed ? 'failed' : 'analyzing',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
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
    required this.broadcastMode,
    required this.mentionOpen,
    required this.mentionIndex,
    required this.mentionCandidates,
    required this.canTrigger,
    required this.triggerCheckinBusy,
    required this.triggerSummaryBusy,
    required this.onChanged,
    required this.onPickMention,
    required this.onToggleBroadcast,
    required this.onTriggerCheckin,
    required this.onTriggerTeamSummary,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool broadcastMode;
  final bool mentionOpen;
  final int mentionIndex;
  final List<ProjectMember> mentionCandidates;
  final bool canTrigger;
  final bool triggerCheckinBusy;
  final bool triggerSummaryBusy;
  final ValueChanged<String> onChanged;
  final ValueChanged<ProjectMember> onPickMention;
  final VoidCallback onToggleBroadcast;
  final VoidCallback onTriggerCheckin;
  final VoidCallback onTriggerTeamSummary;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final media = MediaQuery.of(context);
    final compact = media.size.width < 760;
    final composerRadius = BorderRadius.circular(
      tokens.themeKey == MaiaThemeKey.brutalist ? 0 : 18,
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.backgroundRaised,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mentionOpen && mentionCandidates.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    constraints: const BoxConstraints(maxWidth: 360),
                    decoration: tokens.surfaceDecoration(withShadow: true),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in mentionCandidates.indexed)
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            selected: entry.$1 == mentionIndex,
                            selectedTileColor: tokens.accentSoft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                tokens.radius.clamp(0, 10),
                              ),
                            ),
                            leading: AvatarWidget(
                              name: entry.$2.user?.name ?? 'Member',
                              avatarUrl: entry.$2.user?.avatarUrl,
                              size: 26,
                            ),
                            title: Text(
                              entry.$2.user?.name ?? 'Member',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: entry.$2.user?.title.isEmpty ?? true
                                ? null
                                : Text(entry.$2.user!.title),
                            onTap: () => onPickMention(entry.$2),
                          ),
                      ],
                    ),
                  ),
                ),
              if (canTrigger && !broadcastMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TriggerMenuButton(
                      disabled:
                          sending || triggerCheckinBusy || triggerSummaryBusy,
                      triggerCheckinBusy: triggerCheckinBusy,
                      triggerSummaryBusy: triggerSummaryBusy,
                      onTriggerCheckin: onTriggerCheckin,
                      onTriggerTeamSummary: onTriggerTeamSummary,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, compact ? 8 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton.filledTonal(
                      tooltip: broadcastMode
                          ? 'Disable broadcast'
                          : 'Broadcast to everyone',
                      onPressed: sending ? null : onToggleBroadcast,
                      style: IconButton.styleFrom(
                        backgroundColor: broadcastMode
                            ? tokens.accent
                            : tokens.backgroundCard,
                        foregroundColor: broadcastMode
                            ? tokens.accentInk
                            : tokens.accent,
                      ),
                      icon: const Icon(Icons.campaign_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: compact ? 16 : null,
                        ),
                        decoration: InputDecoration(
                          hintText: broadcastMode
                              ? 'Broadcast to everyone'
                              : 'Message Maia',
                          hintStyle: TextStyle(color: tokens.faint),
                          filled: true,
                          fillColor: tokens.backgroundCard,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: composerRadius,
                            borderSide: BorderSide(color: tokens.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: composerRadius,
                            borderSide: BorderSide(
                              color: broadcastMode
                                  ? tokens.accent
                                  : tokens.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: composerRadius,
                            borderSide: BorderSide(color: tokens.accent),
                          ),
                          hoverColor: tokens.accentSoft,
                        ),
                        onChanged: onChanged,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.project,
    required this.teamStatus,
    required this.currentUserId,
    required this.activeMemberId,
    required this.isAdmin,
    required this.refreshTick,
    required this.onCollapse,
    required this.onSelectMember,
  });

  final ProjectWithMembers project;
  final List<MemberStatus> teamStatus;
  final String? currentUserId;
  final String? activeMemberId;
  final bool isAdmin;
  final int refreshTick;
  final VoidCallback onCollapse;
  final ValueChanged<MemberStatus> onSelectMember;

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
          ProjectContextPanel(
            projectId: project.id,
            isAdmin: isAdmin,
            refreshTick: refreshTick,
          ),
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
              itemCount: _statuses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final status = _statuses[index];
                final name = status.user.name;
                final selected =
                    status.userId == activeMemberId ||
                    (status.userId == currentUserId && activeMemberId == null);
                return ListTile(
                  selected: selected,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: AvatarWidget(
                    name: name,
                    avatarUrl: status.user.avatarUrl,
                    size: 30,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.text),
                  ),
                  subtitle: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(status.role, style: TextStyle(color: tokens.faint)),
                      if (status.hasBlocker)
                        Text(
                          '${status.blockerCount} blocker${status.blockerCount == 1 ? '' : 's'}',
                          style: TextStyle(color: tokens.danger),
                        ),
                      if (status.relaysWithYou > 0)
                        Text(
                          '${status.relaysWithYou} relay${status.relaysWithYou == 1 ? '' : 's'}',
                          style: TextStyle(color: tokens.accent),
                        ),
                    ],
                  ),
                  trailing: Icon(
                    isAdmin ? Icons.timeline_rounded : Icons.send_rounded,
                    size: 16,
                    color: tokens.faint,
                  ),
                  onTap: () => onSelectMember(status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<MemberStatus> get _statuses {
    if (teamStatus.isNotEmpty) {
      return teamStatus;
    }
    return project.members
        .map(
          (member) => MemberStatus(
            userId: member.userId,
            user:
                member.user ??
                User(
                  id: member.userId,
                  email: '',
                  name: 'Member',
                  title: '',
                  timezone: '',
                  avatarUrl: null,
                  isActive: true,
                  isSuperAdmin: false,
                  createdAt: member.createdAt,
                  updatedAt: member.createdAt,
                ),
            role: member.role,
            checkedIn: false,
            hasBlocker: false,
            relayCount: 0,
            blockerCount: 0,
            relaysWithYou: 0,
            lastActive: null,
          ),
        )
        .toList(growable: false);
  }
}

class _TriggerMenuButton extends StatelessWidget {
  const _TriggerMenuButton({
    required this.disabled,
    required this.triggerCheckinBusy,
    required this.triggerSummaryBusy,
    required this.onTriggerCheckin,
    required this.onTriggerTeamSummary,
  });

  final bool disabled;
  final bool triggerCheckinBusy;
  final bool triggerSummaryBusy;
  final VoidCallback onTriggerCheckin;
  final VoidCallback onTriggerTeamSummary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final busy = triggerCheckinBusy || triggerSummaryBusy;
    return PopupMenuButton<_TriggerAction>(
      enabled: !disabled,
      tooltip: 'Trigger',
      position: PopupMenuPosition.over,
      onSelected: (action) {
        switch (action) {
          case _TriggerAction.checkin:
            onTriggerCheckin();
          case _TriggerAction.teamSummary:
            onTriggerTeamSummary();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_TriggerAction>(
          value: _TriggerAction.checkin,
          enabled: !triggerCheckinBusy,
          child: _TriggerMenuItem(
            icon: Icons.flash_on_rounded,
            title: triggerCheckinBusy
                ? 'Starting check-in...'
                : 'On-demand check-in',
            subtitle: 'Ask check-in-enabled members now',
          ),
        ),
        PopupMenuItem<_TriggerAction>(
          value: _TriggerAction.teamSummary,
          enabled: !triggerSummaryBusy,
          child: _TriggerMenuItem(
            icon: Icons.summarize_outlined,
            title: triggerSummaryBusy ? 'Starting summary...' : 'Team summary',
            subtitle: 'Generate summaries and team digest',
          ),
        ),
      ],
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: tokens.backgroundCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SpinnerWidget(size: 14)
              else
                Icon(Icons.bolt_rounded, size: 15, color: tokens.dim),
              const SizedBox(width: 6),
              Text(
                'Trigger',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.dim,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_less_rounded, size: 16, color: tokens.faint),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TriggerAction { checkin, teamSummary }

class _TriggerMenuItem extends StatelessWidget {
  const _TriggerMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Row(
      children: [
        Icon(icon, size: 18, color: tokens.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: tokens.faint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TriggerConfirmDialog extends StatelessWidget {
  const _TriggerConfirmDialog({
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  final String title;
  final String body;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _BroadcastConfirmDialog extends StatelessWidget {
  const _BroadcastConfirmDialog({required this.project, required this.preview});

  final ProjectWithMembers project;
  final String preview;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final audienceSize = (project.members.length - 1).clamp(0, 9999);
    return AlertDialog(
      backgroundColor: tokens.backgroundRaised,
      title: Row(
        children: [
          Icon(Icons.campaign_rounded, color: tokens.accent),
          const SizedBox(width: 8),
          const Text('Broadcast to the team?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will go to $audienceSize teammate${audienceSize == 1 ? '' : 's'} in ${project.name}.',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.backgroundCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.accent),
            ),
            child: Text(preview),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Send broadcast'),
        ),
      ],
    );
  }
}

class _RelaySheet extends StatefulWidget {
  const _RelaySheet({
    required this.target,
    required this.onClose,
    required this.onSubmit,
  });

  final MemberStatus target;
  final VoidCallback onClose;
  final Future<void> Function(String body) onSubmit;

  @override
  State<_RelaySheet> createState() => _RelaySheetState();
}

class _RelaySheetState extends State<_RelaySheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    await widget.onSubmit(body);
    if (mounted) {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final firstName = widget.target.user.name.split(' ').first;
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: tokens.backgroundRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AvatarWidget(
                      name: widget.target.user.name,
                      avatarUrl: widget.target.user.avatarUrl,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.target.user.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            widget.target.relaysWithYou > 0
                                ? '${widget.target.relaysWithYou} relay${widget.target.relaysWithYou == 1 ? '' : 's'} between you'
                                : 'Send your first relay',
                            style: TextStyle(color: tokens.dim, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _sending ? null : widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Write casually. Maia will rephrase for $firstName.',
                    filled: true,
                    fillColor: tokens.backgroundCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sending ? null : widget.onClose,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _submit,
                        icon: _sending
                            ? const SpinnerWidget(size: 16)
                            : const Icon(Icons.send_rounded),
                        label: const Text('Send via Maia'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberTimelineView extends StatefulWidget {
  const _MemberTimelineView({
    required this.project,
    required this.memberId,
    required this.currentUserId,
    required this.messages,
    required this.loading,
    required this.sending,
    required this.onBack,
    required this.onRelay,
    required this.onToggleResolved,
  });

  final ProjectWithMembers project;
  final String memberId;
  final String? currentUserId;
  final List<Message> messages;
  final bool loading;
  final bool sending;
  final VoidCallback onBack;
  final Future<void> Function(String body) onRelay;
  final Future<void> Function(String messageId, bool nextResolved)
  onToggleResolved;

  @override
  State<_MemberTimelineView> createState() => _MemberTimelineViewState();
}

class _MemberTimelineViewState extends State<_MemberTimelineView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    ProjectMember? member;
    for (final item in widget.project.members) {
      if (item.userId == widget.memberId) {
        member = item;
        break;
      }
    }
    final user = member?.user;
    final name = user?.name ?? 'Member';
    final messagesById = {
      for (final message in widget.messages) message.id: message,
    };
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to chat',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              AvatarWidget(name: name, avatarUrl: user?.avatarUrl, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.loading && widget.messages.isEmpty
              ? const Center(child: SpinnerWidget())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: widget.messages[index],
                    project: widget.project,
                    currentUserId: widget.currentUserId,
                    messagesById: messagesById,
                    myThreadId: null,
                    onToggleResolved: widget.onToggleResolved,
                    onConfirmMediaRelay: (body) async {},
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Relay to ${name.split(' ').first}',
                    filled: true,
                    fillColor: tokens.backgroundCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onSubmitted: (_) async {
                    final body = _controller.text;
                    _controller.clear();
                    await widget.onRelay(body);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: widget.sending
                    ? null
                    : () async {
                        final body = _controller.text;
                        _controller.clear();
                        await widget.onRelay(body);
                      },
                icon: widget.sending
                    ? const SpinnerWidget(size: 16)
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelayAckPill extends StatefulWidget {
  const _RelayAckPill({required this.message, required this.project});

  final Message message;
  final ProjectWithMembers project;

  @override
  State<_RelayAckPill> createState() => _RelayAckPillState();
}

class _RelayAckPillState extends State<_RelayAckPill> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final extra = widget.message.extra ?? const <String, dynamic>{};
    final kind = extra['kind']?.toString();
    final broadcast = kind == 'broadcast_sent';
    final targetName = extra['target_name']?.toString();
    final sentBody = extra['sent_body']?.toString();
    final audienceSize = extra['audience_size']?.toString();
    final attachments = messageAttachmentsOf(widget.message);
    final label = broadcast
        ? 'Broadcast to ${audienceSize ?? 'team'}'
        : 'Relayed to ${targetName?.split(' ').first ?? 'teammate'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActionChip(
              avatar: Icon(
                broadcast ? Icons.campaign_rounded : Icons.call_made_rounded,
                size: 16,
                color: tokens.accent,
              ),
              label: Text(label),
              onPressed: () => setState(() => _expanded = !_expanded),
              backgroundColor: tokens.accent.withValues(alpha: 0.10),
              side: BorderSide(color: tokens.accent.withValues(alpha: 0.32)),
            ),
            if (_expanded &&
                ((sentBody != null && sentBody.isNotEmpty) ||
                    attachments.isNotEmpty))
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.backgroundCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sentBody != null && sentBody.isNotEmpty) Text(sentBody),
                    if (attachments.isNotEmpty) ...[
                      if (sentBody != null && sentBody.isNotEmpty)
                        const SizedBox(height: 8),
                      _AttachmentGrid(attachments: attachments),
                    ],
                  ],
                ),
              ),
            if (!_expanded && attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _AttachmentGrid(attachments: attachments),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(
                DateFormat('h:mm a').format(widget.message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.faint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboundRelayPill extends StatefulWidget {
  const _InboundRelayPill({
    required this.message,
    required this.project,
    required this.currentUserId,
    required this.messagesById,
    required this.onRelayReply,
  });

  final Message message;
  final ProjectWithMembers project;
  final String? currentUserId;
  final Map<String, Message> messagesById;
  final Future<void> Function(Message message, String body)? onRelayReply;

  @override
  State<_InboundRelayPill> createState() => _InboundRelayPillState();
}

class _InboundRelayPillState extends State<_InboundRelayPill> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (_expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MessageBubble(
            message: widget.message,
            project: widget.project,
            currentUserId: widget.currentUserId,
            messagesById: widget.messagesById,
            myThreadId: null,
            onToggleResolved: (messageId, nextResolved) async {},
            onConfirmMediaRelay: (body) async {},
            forceExpandedRelay: true,
          ),
          if (widget.onRelayReply != null)
            _InlineRelayReplyComposer(
              onSubmit: (body) => widget.onRelayReply!(widget.message, body),
            ),
        ],
      );
    }
    final tokens = context.maia;
    final isBroadcast =
        widget.message.recipient?.kind == 'everyone' ||
        widget.message.toAudience == 'everyone';
    final sender =
        _memberName(
          widget.project,
          widget.message.fromUserId,
        )?.split(' ').first ??
        'Teammate';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActionChip(
              avatar: Icon(
                isBroadcast
                    ? Icons.campaign_rounded
                    : Icons.call_received_rounded,
                color: tokens.accentInk,
                size: 16,
              ),
              label: Text(
                isBroadcast ? 'Broadcast from $sender' : 'Relay from $sender',
              ),
              onPressed: () => setState(() => _expanded = true),
              backgroundColor: tokens.accent,
              labelStyle: TextStyle(color: tokens.accentInk),
              side: BorderSide(color: tokens.accent),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(
                DateFormat('h:mm a').format(widget.message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.faint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineRelayReplyComposer extends StatefulWidget {
  const _InlineRelayReplyComposer({required this.onSubmit});

  final Future<void> Function(String body) onSubmit;

  @override
  State<_InlineRelayReplyComposer> createState() =>
      _InlineRelayReplyComposerState();
}

class _InlineRelayReplyComposerState extends State<_InlineRelayReplyComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    await widget.onSubmit(body);
    if (mounted) {
      _controller.clear();
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 2, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reply via Maia',
                filled: true,
                fillColor: tokens.backgroundCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Reply',
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SpinnerWidget(size: 14)
                : const Icon(Icons.reply_rounded),
          ),
        ],
      ),
    );
  }
}

class _SummaryBubble extends StatefulWidget {
  const _SummaryBubble({
    required this.message,
    required this.currentUserId,
    required this.messagesById,
    required this.onToggleResolved,
  });

  final Message message;
  final String? currentUserId;
  final Map<String, Message> messagesById;
  final Future<void> Function(String messageId, bool nextResolved)
  onToggleResolved;

  @override
  State<_SummaryBubble> createState() => _SummaryBubbleState();
}

class _SummaryBubbleState extends State<_SummaryBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final extra = widget.message.extra ?? const <String, dynamic>{};
    final summary = _mapValue(extra['summary']);
    final aboutName = extra['about_user_name']?.toString() ?? 'Member';
    final aboutUserId = extra['about_user_id']?.toString();
    final firstName = aboutName.split(' ').first;
    final done = _stringItems(summary['done']);
    final blocked = _blockedItems(summary['blocked']);
    final next = _stringItems(summary['next']);
    final highlight = summary['highlight']?.toString().trim() ?? '';
    if (done.isEmpty && blocked.isEmpty && next.isEmpty && highlight.isEmpty) {
      final checkedIn = summary['checked_in'] == true;
      final text = summary['checked_in'] == false
          ? "$firstName didn't check in today."
          : checkedIn
          ? 'Quiet day for $firstName. Nothing to log.'
          : 'No activity to summarize.';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: TextStyle(color: tokens.dim, fontStyle: FontStyle.italic),
        ),
      );
    }
    final canResolve =
        widget.currentUserId != null &&
        aboutUserId != null &&
        widget.currentUserId == aboutUserId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionChip(
                avatar: Icon(
                  Icons.fact_check_rounded,
                  color: blocked.isEmpty ? tokens.accent : tokens.danger,
                  size: 16,
                ),
                label: Text('$firstName · daily check-in'),
                onPressed: () => setState(() => _expanded = !_expanded),
                backgroundColor: tokens.backgroundCard,
                side: BorderSide(
                  color: blocked.isEmpty ? tokens.border : tokens.danger,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (done.isNotEmpty)
                      Text(
                        '${done.length} done',
                        style: TextStyle(color: tokens.success),
                      ),
                    if (blocked.isNotEmpty)
                      Text(
                        '${blocked.length} blocker${blocked.length == 1 ? '' : 's'}',
                        style: TextStyle(color: tokens.danger),
                      ),
                    if (next.isNotEmpty)
                      Text(
                        '${next.length} next',
                        style: TextStyle(color: tokens.dim),
                      ),
                    Text(
                      DateFormat('h:mm a').format(widget.message.createdAt),
                      style: TextStyle(color: tokens.faint),
                    ),
                  ],
                ),
              ),
              if (_expanded)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: blocked.isEmpty ? tokens.border : tokens.danger,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (highlight.isNotEmpty) ...[
                        Text(
                          highlight,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _SummarySection(
                        title: 'Done',
                        items: done,
                        color: tokens.success,
                      ),
                      if (blocked.isNotEmpty)
                        _BlockedSummarySection(
                          items: blocked,
                          messagesById: widget.messagesById,
                          canResolve: canResolve,
                          onToggleResolved: widget.onToggleResolved,
                        ),
                      _SummarySection(
                        title: 'Next',
                        items: next,
                        color: tokens.accent,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }
}

class _BlockedSummarySection extends StatelessWidget {
  const _BlockedSummarySection({
    required this.items,
    required this.messagesById,
    required this.canResolve,
    required this.onToggleResolved,
  });

  final List<_BlockedItem> items;
  final Map<String, Message> messagesById;
  final bool canResolve;
  final Future<void> Function(String messageId, bool nextResolved)
  onToggleResolved;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blocked',
            style: TextStyle(
              color: tokens.danger,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canResolve && item.sourceMessageIds.isNotEmpty)
                    _ResolveButton(
                      resolved:
                          item.allResolved ??
                          item.sourceMessageIds.every(
                            (id) => messagesById[id]?.resolvedAt != null,
                          ),
                      onPressed: () {
                        final resolved =
                            item.allResolved ??
                            item.sourceMessageIds.every(
                              (id) => messagesById[id]?.resolvedAt != null,
                            );
                        for (final id in item.sourceMessageIds) {
                          unawaited(onToggleResolved(id, !resolved));
                        }
                      },
                    )
                  else
                    Text('• ', style: TextStyle(color: tokens.danger)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.text,
                      style: TextStyle(
                        decoration: (item.allResolved ?? false)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
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

class _ResolveButton extends StatelessWidget {
  const _ResolveButton({required this.resolved, required this.onPressed});

  final bool resolved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Tooltip(
      message: resolved ? 'Reflag' : 'Mark resolved',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Icon(
          resolved ? Icons.undo_rounded : Icons.check_circle_rounded,
          size: 18,
          color: resolved ? tokens.success : tokens.danger,
        ),
      ),
    );
  }
}

class _BlockedItem {
  const _BlockedItem({
    required this.text,
    required this.sourceMessageIds,
    required this.allResolved,
  });

  final String text;
  final List<String> sourceMessageIds;
  final bool? allResolved;
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return <String, dynamic>{};
}

List<String> _stringItems(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const <String>[];
}

List<_BlockedItem> _blockedItems(Object? value) {
  if (value is! List) {
    return const <_BlockedItem>[];
  }
  return value
      .map((item) {
        if (item is String) {
          return _BlockedItem(
            text: item,
            sourceMessageIds: const <String>[],
            allResolved: null,
          );
        }
        final data = _mapValue(item);
        return _BlockedItem(
          text: data['text']?.toString() ?? '',
          sourceMessageIds: _stringItems(data['source_message_ids']),
          allResolved: data['all_resolved'] is bool
              ? data['all_resolved'] as bool
              : null,
        );
      })
      .where((item) => item.text.trim().isNotEmpty)
      .toList(growable: false);
}

String? _memberName(ProjectWithMembers project, String? userId) {
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
  return mergeMessagesById(current, incoming);
}

List<Message> mergeMessagesById(List<Message> current, List<Message> incoming) {
  final byId = <String, Message>{
    for (final message in current) message.id: message,
  };
  for (final message in incoming) {
    final prior = byId[message.id];
    byId[message.id] = prior == null
        ? message
        : prior.copyWith(
            threadId: message.threadId,
            type: message.type,
            body: message.body,
            tone: message.tone,
            fromUserId: message.fromUserId,
            toUserId: message.toUserId,
            toAudience: message.toAudience,
            recipient: message.recipient,
            repliesToMessageId: message.repliesToMessageId,
            replyToPreview: message.replyToPreview,
            originalText: message.originalText,
            extra: message.extra ?? prior.extra,
            promptVersionId: message.promptVersionId,
            createdAt: message.createdAt,
            resolvedAt: message.resolvedAt,
          );
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

Duration chatPollInterval({
  required bool isSending,
  required bool inferenceActive,
}) {
  return isSending || inferenceActive ? _activePollInterval : _idlePollInterval;
}

String _messageFor(Object error) {
  if (error is ApiException && error.message.isNotEmpty) {
    return error.message;
  }
  return 'Failed to load project chat.';
}

String _schedulerMessageFor(Object error) {
  if (error is ApiException && error.status == 403) {
    return 'Project admin or workspace admin access required.';
  }
  if (error is ApiException && error.message.isNotEmpty) {
    return error.message;
  }
  return 'Could not start trigger.';
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
