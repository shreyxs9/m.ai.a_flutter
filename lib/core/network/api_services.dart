import 'api_client.dart';

class AuthService {
  const AuthService(this.client);

  final ApiClient client;
}

class TenantService {
  const TenantService(this.client);

  final ApiClient client;
}

class ProjectService {
  const ProjectService(this.client);

  final ApiClient client;
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
