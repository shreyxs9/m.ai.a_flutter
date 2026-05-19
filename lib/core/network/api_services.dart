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
}

class SseService {
  const SseService(this.client);

  final ApiClient client;
}

class GoogleSheetsService {
  const GoogleSheetsService(this.client);

  final ApiClient client;
}
