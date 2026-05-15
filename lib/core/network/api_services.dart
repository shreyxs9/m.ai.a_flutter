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
    return response?.map(Tenant.fromJson).toList(growable: false) ??
        <Tenant>[];
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
}

class MessageService {
  const MessageService(this.client);

  final ApiClient client;
}

class UserService {
  const UserService(this.client);

  final ApiClient client;
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
