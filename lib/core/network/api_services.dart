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

  Future<List<Message>> sendToThread(String threadId, String body) async {
    final response = await client.post<List<dynamic>>(
      '/messages/thread/${Uri.encodeComponent(threadId)}',
      body: <String, dynamic>{'body': body},
    );
    return response?.map(Message.fromJson).toList(growable: false) ??
        <Message>[];
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
