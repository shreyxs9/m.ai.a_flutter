import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'api_client.dart';
import '../../models/models.dart';

class AuthService {
  const AuthService(this.client);

  final ApiClient client;

  Future<User?> getMe() {
    return client.get('/auth/me', parse: User.fromJson);
  }

  Future<User?> updateTimezone(String timezone) {
    return client.patch(
      '/auth/me/timezone',
      body: {'timezone': timezone},
      parse: User.fromJson,
    );
  }

  Future<User?> updateTitle(String title) {
    return client.patch(
      '/auth/me/title',
      body: {'title': title},
      parse: User.fromJson,
    );
  }

  Future<String> getLoginUrl() async {
    final response = await client.get<Map<String, dynamic>>('/auth/login');
    return response?['url']?.toString() ?? '';
  }

  Future<GoogleSheetsStatus?> googleSheetsStatus() {
    return client.get(
      '/auth/google-sheets/status',
      parse: GoogleSheetsStatus.fromJson,
    );
  }

  Future<String> connectGoogleSheetsUrl() async {
    final response = await client.get<Map<String, dynamic>>(
      '/auth/google-sheets/connect',
    );
    return response?['url']?.toString() ?? '';
  }

  Future<void> disconnectGoogleSheets() async {
    await client.delete<void>('/auth/google-sheets/disconnect');
  }

  Future<List<Map<String, dynamic>>> devLogin() async {
    final response = await client.get<List<dynamic>>('/auth/dev-login');
    return response
            ?.whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry('$key', value)))
            .toList(growable: false) ??
        <Map<String, dynamic>>[];
  }
}

class TenantService {
  const TenantService(this.client);

  final ApiClient client;

  Future<List<Tenant>> list() async {
    final response = await client.get<List<dynamic>>('/tenants/');
    return response?.map(Tenant.fromJson).toList(growable: false) ?? <Tenant>[];
  }

  Future<Tenant?> get(String id) {
    return client.get(
      '/tenants/${Uri.encodeComponent(id)}',
      parse: Tenant.fromJson,
    );
  }

  Future<Tenant?> create(String name) {
    return client.post(
      '/tenants/',
      body: {'name': name},
      parse: Tenant.fromJson,
    );
  }

  Future<TenantPreview?> previewByInvite(String code) {
    return client.get(
      '/tenants/by-invite/${Uri.encodeComponent(code)}',
      parse: TenantPreview.fromJson,
    );
  }

  Future<TenantJoinResult?> joinByInvite(String code) {
    return client.post(
      '/tenants/join-by-invite',
      body: {'invite_code': code},
      parse: TenantJoinResult.fromJson,
    );
  }
}

class ProjectService {
  const ProjectService(this.client);

  final ApiClient client;

  static String normalizeInviteCode(String inviteCode) {
    return inviteCode.trim().toUpperCase();
  }

  Future<List<ProjectListItem>> list({bool includeArchived = false}) async {
    final response = await client.get<List<dynamic>>(
      '/projects/',
      queryParameters: includeArchived
          ? const <String, dynamic>{'include_archived': true}
          : null,
    );
    return response?.map(ProjectListItem.fromJson).toList(growable: false) ??
        <ProjectListItem>[];
  }

  Future<Project?> create({
    required String name,
    String? description,
    String? icon,
  }) {
    final body = <String, dynamic>{'name': name};
    if (description != null) {
      body['description'] = description;
    }
    if (icon != null) {
      body['icon'] = icon;
    }
    return client.post('/projects/', body: body, parse: Project.fromJson);
  }

  Future<ProjectWithMembers?> get(String projectId) {
    return client.get(
      '/projects/${Uri.encodeComponent(projectId)}',
      parse: ProjectWithMembers.fromJson,
    );
  }

  Future<List<MemberStatus>> teamStatus(String projectId) async {
    final response = await client.get<List<dynamic>>(
      '/projects/${Uri.encodeComponent(projectId)}/team-status',
    );
    return response?.map(MemberStatus.fromJson).toList(growable: false) ??
        <MemberStatus>[];
  }

  Future<List<Message>> memberTimeline(String projectId, String userId) async {
    final response = await client.get<List<dynamic>>(
      '/projects/${Uri.encodeComponent(projectId)}/members/${Uri.encodeComponent(userId)}/timeline',
    );
    return response?.map(Message.fromJson).toList(growable: false) ??
        <Message>[];
  }

  Future<Project?> update(
    String projectId, {
    String? name,
    String? description,
    String? icon,
    String? checkinTime,
    String? checkinTimezone,
    int? digestDelayMinutes,
    bool? isArchived,
  }) {
    final body = <String, dynamic>{};
    if (name != null) {
      body['name'] = name;
    }
    if (description != null) {
      body['description'] = description;
    }
    if (icon != null) {
      body['icon'] = icon;
    }
    if (checkinTime != null) {
      body['checkin_time'] = checkinTime;
    }
    if (checkinTimezone != null) {
      body['checkin_timezone'] = checkinTimezone;
    }
    if (digestDelayMinutes != null) {
      body['digest_delay_minutes'] = digestDelayMinutes;
    }
    if (isArchived != null) {
      body['is_archived'] = isArchived;
    }
    return client.patch(
      '/projects/${Uri.encodeComponent(projectId)}',
      body: body,
      parse: Project.fromJson,
    );
  }

  Future<ProjectMember?> addMember(String projectId, String userId) {
    return client.post(
      '/projects/${Uri.encodeComponent(projectId)}/members',
      body: {'user_id': userId},
      parse: ProjectMember.fromJson,
    );
  }

  Future<ProjectMember?> updateMember(
    String projectId,
    String userId, {
    String? role,
    bool? checkinEnabled,
  }) {
    final body = <String, dynamic>{};
    if (role != null) {
      body['role'] = role;
    }
    if (checkinEnabled != null) {
      body['checkin_enabled'] = checkinEnabled;
    }
    return client.patch(
      '/projects/${Uri.encodeComponent(projectId)}/members/${Uri.encodeComponent(userId)}',
      body: body,
      parse: ProjectMember.fromJson,
    );
  }

  Future<void> removeMember(String projectId, String userId) async {
    await client.delete<void>(
      '/projects/${Uri.encodeComponent(projectId)}/members/${Uri.encodeComponent(userId)}',
    );
  }

  Future<ProjectGoals?> goals(String projectId) {
    return client.get(
      '/projects/${Uri.encodeComponent(projectId)}/goals',
      parse: ProjectGoals.fromJson,
    );
  }

  Future<List<ProjectGoalsHistoryItem>> goalsHistory(String projectId) async {
    final response = await client.get<List<dynamic>>(
      '/projects/${Uri.encodeComponent(projectId)}/goals/history',
    );
    return response
            ?.map(ProjectGoalsHistoryItem.fromJson)
            .toList(growable: false) ??
        <ProjectGoalsHistoryItem>[];
  }

  Future<ProjectState?> state(String projectId) {
    return client.get(
      '/projects/${Uri.encodeComponent(projectId)}/state',
      parse: ProjectState.fromJson,
    );
  }

  Future<List<ProjectStateHistoryItem>> stateHistory(String projectId) async {
    final response = await client.get<List<dynamic>>(
      '/projects/${Uri.encodeComponent(projectId)}/state/history',
    );
    return response
            ?.map(ProjectStateHistoryItem.fromJson)
            .toList(growable: false) ??
        <ProjectStateHistoryItem>[];
  }

  Future<List<ProjectSheet>> listSheets(String projectId) async {
    final response = await client.get<List<dynamic>>(
      '/projects/${Uri.encodeComponent(projectId)}/sheets',
    );
    return response?.map(ProjectSheet.fromJson).toList(growable: false) ??
        <ProjectSheet>[];
  }

  Future<ProjectSheet?> attachSheet(
    String projectId, {
    required String googleSheetId,
    required String label,
    required String schemaHint,
  }) {
    return client.post(
      '/projects/${Uri.encodeComponent(projectId)}/sheets',
      body: {
        'google_sheet_id': googleSheetId,
        'label': label,
        'schema_hint': schemaHint,
      },
      parse: ProjectSheet.fromJson,
    );
  }

  Future<void> detachSheet(String projectId, String sheetId) async {
    await client.delete<void>(
      '/projects/${Uri.encodeComponent(projectId)}/sheets/${Uri.encodeComponent(sheetId)}',
    );
  }

  Future<Project?> archive(String projectId) {
    return client.post(
      '/projects/${Uri.encodeComponent(projectId)}/archive',
      parse: Project.fromJson,
    );
  }

  Future<Project?> unarchive(String projectId) {
    return client.post(
      '/projects/${Uri.encodeComponent(projectId)}/unarchive',
      parse: Project.fromJson,
    );
  }

  Future<JoinByInviteResult?> joinByInvite(String inviteCode) {
    return client.post(
      '/projects/join-by-invite',
      body: {'invite_code': normalizeInviteCode(inviteCode)},
      parse: JoinByInviteResult.fromJson,
    );
  }
}

class ThreadService {
  const ThreadService(this.client);

  final ApiClient client;

  Future<Thread?> getOrCreateForProject(String projectId) {
    return client.get(
      '/threads/project/${Uri.encodeComponent(projectId)}',
      parse: Thread.fromJson,
    );
  }

  Future<List<Message>> listMessages(
    String threadId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await client.get<List<dynamic>>(
      '/threads/${Uri.encodeComponent(threadId)}/messages',
      queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    return response?.map(Message.fromJson).toList(growable: false) ??
        <Message>[];
  }
}

class MessageService {
  const MessageService(this.client);

  final ApiClient client;

  Future<List<Message>> sendToThread(
    String threadId,
    String body, {
    List<String> mentionUserIds = const <String>[],
    String? repliesToMessageId,
  }) async {
    final payload = <String, dynamic>{'body': body};
    if (mentionUserIds.isNotEmpty) {
      payload['mention_user_ids'] = mentionUserIds;
    }
    if (repliesToMessageId != null && repliesToMessageId.isNotEmpty) {
      payload['replies_to_message_id'] = repliesToMessageId;
    }
    final response = await client.post<List<dynamic>>(
      '/messages/thread/${Uri.encodeComponent(threadId)}',
      body: payload,
    );
    return response?.map(Message.fromJson).toList(growable: false) ??
        <Message>[];
  }

  Future<List<Message>> relay({
    required String projectId,
    String? targetUserId,
    required String body,
    String? repliesToMessageId,
  }) async {
    final payload = <String, dynamic>{'body': body};
    if (targetUserId != null && targetUserId.isNotEmpty) {
      payload['target_user_id'] = targetUserId;
    }
    if (repliesToMessageId != null && repliesToMessageId.isNotEmpty) {
      payload['replies_to_message_id'] = repliesToMessageId;
    }
    final response = await client.post<List<dynamic>>(
      '/messages/relay/${Uri.encodeComponent(projectId)}',
      body: payload,
    );
    return response?.map(Message.fromJson).toList(growable: false) ??
        <Message>[];
  }

  Future<List<Message>> broadcast({
    required String projectId,
    required String body,
    String? repliesToMessageId,
  }) async {
    final payload = <String, dynamic>{'body': body};
    if (repliesToMessageId != null && repliesToMessageId.isNotEmpty) {
      payload['replies_to_message_id'] = repliesToMessageId;
    }
    final response = await client.post<List<dynamic>>(
      '/messages/broadcast/${Uri.encodeComponent(projectId)}',
      body: payload,
    );
    return response?.map(Message.fromJson).toList(growable: false) ??
        <Message>[];
  }

  Future<Message?> resolve(String messageId) {
    return client.post(
      '/messages/${Uri.encodeComponent(messageId)}/resolve',
      parse: Message.fromJson,
    );
  }

  Future<Message?> unresolve(String messageId) {
    return client.post(
      '/messages/${Uri.encodeComponent(messageId)}/unresolve',
      parse: Message.fromJson,
    );
  }
}

class UserService {
  const UserService(this.client);

  final ApiClient client;

  Future<User?> update(String userId, {String? name}) {
    final body = <String, dynamic>{};
    if (name != null) {
      body['name'] = name;
    }
    return client.patch(
      '/users/${Uri.encodeComponent(userId)}',
      body: body,
      parse: User.fromJson,
    );
  }

  Future<List<TenantMembership>> tenantMembers() async {
    final response = await client.get<List<dynamic>>('/users/tenant/members');
    return response?.map(TenantMembership.fromJson).toList(growable: false) ??
        <TenantMembership>[];
  }
}

class AdminService {
  const AdminService(this.client);

  final ApiClient client;

  Future<TenantMembership?> updateTenantMemberRole({
    required String tenantId,
    required String userId,
    required String role,
  }) {
    return client.patch(
      '/admin/tenants/${Uri.encodeComponent(tenantId)}/members/${Uri.encodeComponent(userId)}',
      body: {'role': role},
      parse: TenantMembership.fromJson,
    );
  }

  Future<void> removeTenantMember({
    required String tenantId,
    required String userId,
  }) async {
    await client.delete<void>(
      '/admin/tenants/${Uri.encodeComponent(tenantId)}/members/${Uri.encodeComponent(userId)}',
    );
  }
}

class SearchService {
  const SearchService(this.client);

  final ApiClient client;

  Future<SearchResponse?> messages(String projectId, String query) {
    return client.get(
      '/search/messages/${Uri.encodeComponent(projectId)}',
      queryParameters: <String, dynamic>{'q': query},
      parse: SearchResponse.fromJson,
    );
  }
}

class PushService {
  const PushService(this.client);

  final ApiClient client;

  Future<void> registerToken(String token, String platform) async {
    await client.post<void>(
      '/me/push-tokens',
      body: <String, dynamic>{'token': token, 'platform': platform},
    );
  }

  Future<void> deleteToken(String token) async {
    await client.delete<void>('/me/push-tokens/${Uri.encodeComponent(token)}');
  }
}

class SseService {
  const SseService(this.client);

  final ApiClient client;

  SseStreamController sendAndStream(
    String threadId,
    String body,
    SseCallback onEvent, {
    String? repliesToMessageId,
    List<String> mentionUserIds = const <String>[],
    void Function(String sessionId)? onSession,
  }) {
    final cancelToken = CancelToken();
    String? sessionId;
    var lastSeq = 0;

    void trackingEvent(String event, SseJsonMap data) {
      final rawSeq = data['seq'];
      if (rawSeq is num && rawSeq > lastSeq) {
        lastSeq = rawSeq.toInt();
      }
      if (event == 'session' && data['session_id'] is String) {
        sessionId = data['session_id'] as String;
        onSession?.call(sessionId!);
      }
      onEvent(event, data);
    }

    unawaited(() async {
      try {
        final payload = <String, dynamic>{'body': body};
        if (repliesToMessageId != null && repliesToMessageId.isNotEmpty) {
          payload['replies_to_message_id'] = repliesToMessageId;
        }
        if (mentionUserIds.isNotEmpty) {
          payload['mention_user_ids'] = mentionUserIds;
        }
        final response = await _requestStream(
          '/sse/send/${Uri.encodeComponent(threadId)}',
          method: 'POST',
          body: payload,
          cancelToken: cancelToken,
        );
        final headerSession =
            response.headers.value('X-Maia-Session-Id') ??
            response.headers.value('x-maia-session-id');
        if (headerSession != null && sessionId == null) {
          sessionId = headerSession;
          onSession?.call(headerSession);
        }
        await parseSseByteStream(response.data!.stream, trackingEvent);
      } on DioException catch (error) {
        if (error.type != DioExceptionType.cancel) {
          onEvent('error', {'detail': _streamErrorMessage(error)});
        }
      } catch (error) {
        onEvent('error', {'detail': error.toString()});
      }
    }());

    return SseStreamController(
      abort: cancelToken.cancel,
      getSessionId: () => sessionId,
      getLastSeq: () => lastSeq,
    );
  }

  SseStreamController reconnectStream(
    String sessionId,
    int lastSeq,
    SseCallback onEvent,
  ) {
    final cancelToken = CancelToken();
    var observedSeq = lastSeq;

    void trackingEvent(String event, SseJsonMap data) {
      final rawSeq = data['seq'];
      if (rawSeq is num && rawSeq > observedSeq) {
        observedSeq = rawSeq.toInt();
      }
      onEvent(event, data);
    }

    unawaited(() async {
      try {
        final response = await _requestStream(
          '/sse/stream/${Uri.encodeComponent(sessionId)}',
          queryParameters: <String, dynamic>{'last_seq': lastSeq},
          cancelToken: cancelToken,
        );
        await parseSseByteStream(response.data!.stream, trackingEvent);
      } on DioException catch (error) {
        if (error.type != DioExceptionType.cancel) {
          onEvent('error', {'detail': _streamErrorMessage(error)});
        }
      } catch (error) {
        onEvent('error', {'detail': error.toString()});
      }
    }());

    return SseStreamController(
      abort: cancelToken.cancel,
      getSessionId: () => sessionId,
      getLastSeq: () => observedSeq,
    );
  }

  SseSubscriptionController subscribeThread(
    String threadId,
    SseCallback onEvent,
  ) {
    final controller = SseSubscriptionController();
    var firstConnect = true;
    final random = Random();

    Future<void> connect() async {
      if (controller.stopped) {
        return;
      }
      final cancelToken = CancelToken();
      controller.innerCancelToken = cancelToken;
      final isRotation = !firstConnect;
      firstConnect = false;
      var rotated = false;

      try {
        final response = await _requestStream(
          '/sse/subscribe/${Uri.encodeComponent(threadId)}',
          cancelToken: cancelToken,
        );
        if (isRotation && !controller.stopped) {
          onEvent('resubscribed', <String, dynamic>{});
        }
        await parseSseByteStream(response.data!.stream, (event, data) {
          if (event == 'reconnect') {
            rotated = true;
            return;
          }
          onEvent(event, data);
        });
        if (rotated && !controller.stopped) {
          final jitter = Duration(milliseconds: 100 + random.nextInt(400));
          Timer(jitter, () => unawaited(connect()));
        } else if (!controller.stopped) {
          onEvent('disconnected', <String, dynamic>{});
        }
      } on DioException catch (error) {
        if (error.type != DioExceptionType.cancel && !controller.stopped) {
          onEvent('error', {'detail': _streamErrorMessage(error)});
        }
      } catch (error) {
        if (!controller.stopped) {
          onEvent('error', {'detail': error.toString()});
        }
      }
    }

    unawaited(connect());
    return controller;
  }

  Future<Response<ResponseBody>> _requestStream(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, dynamic>? queryParameters,
    required CancelToken cancelToken,
  }) async {
    final response = await client.dio.request<ResponseBody>(
      path,
      data: body,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(
        method: method,
        responseType: ResponseType.stream,
        headers: const {Headers.acceptHeader: 'text/event-stream'},
      ),
    );
    final status = response.statusCode;
    if (status == null ||
        status < 200 ||
        status >= 300 ||
        response.data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'HTTP ${status ?? 'unknown'}',
      );
    }
    return response;
  }

  String _streamErrorMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status != null) {
      return 'HTTP $status';
    }
    return error.message ?? 'Connection failed';
  }
}

typedef SseJsonMap = Map<String, dynamic>;
typedef SseCallback = void Function(String event, SseJsonMap data);

class SseFrame {
  const SseFrame({required this.event, required this.data});

  final String event;
  final SseJsonMap data;
}

class SseLineParser {
  String? _currentEvent;

  SseFrame? parseLine(String line) {
    final normalized = line.endsWith('\r')
        ? line.substring(0, line.length - 1)
        : line;
    if (normalized.startsWith('event:')) {
      _currentEvent = normalized.substring(6).trimLeft();
      return null;
    }
    if (normalized.startsWith('data:') && _currentEvent != null) {
      final event = _currentEvent!;
      _currentEvent = null;
      try {
        final decoded = jsonDecode(normalized.substring(5).trimLeft());
        if (decoded is Map<String, dynamic>) {
          return SseFrame(event: event, data: decoded);
        }
        if (decoded is Map) {
          return SseFrame(
            event: event,
            data: decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

Future<void> parseSseByteStream(
  Stream<List<int>> stream,
  SseCallback onEvent,
) async {
  final parser = SseLineParser();
  await for (final line
      in stream.transform(utf8.decoder).transform(const LineSplitter())) {
    final frame = parser.parseLine(line);
    if (frame != null) {
      onEvent(frame.event, frame.data);
    }
  }
}

class SseStreamController {
  const SseStreamController({
    required this.abort,
    required this.getSessionId,
    required this.getLastSeq,
  });

  final void Function([Object? reason]) abort;
  final String? Function() getSessionId;
  final int Function() getLastSeq;
}

class SseSubscriptionController {
  bool stopped = false;
  CancelToken? innerCancelToken;

  void abort() {
    stopped = true;
    innerCancelToken?.cancel();
  }
}

class GoogleSheetsService {
  const GoogleSheetsService(this.client);

  final ApiClient client;
}
