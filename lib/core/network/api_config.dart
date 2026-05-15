class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.basePath,
    required this.timeout,
    required this.loginOrigin,
  });

  static const defaultConfig = ApiConfig(
    baseUrl: String.fromEnvironment(
      'MAIA_API_BASE_URL',
      defaultValue: 'https://maia-backend-7vtst4xamq-el.a.run.app',
    ),
    basePath: String.fromEnvironment(
      'MAIA_API_BASE_PATH',
      defaultValue: '/api/v1',
    ),
    timeout: Duration(seconds: 30),
    loginOrigin: String.fromEnvironment(
      'API_ORIGIN',
      defaultValue: String.fromEnvironment(
        'MAIA_API_BASE_URL',
        defaultValue: 'https://maia-backend-7vtst4xamq-el.a.run.app',
      ),
    ),
  );

  final String baseUrl;
  final String basePath;
  final Duration timeout;
  final String loginOrigin;

  String get normalizedBaseUrl {
    final cleanBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final cleanBasePath = basePath.startsWith('/') ? basePath : '/$basePath';
    return '$cleanBaseUrl${cleanBasePath.replaceFirst(RegExp(r'/+$'), '')}';
  }

  String get loginRedirectUrl {
    final cleanBaseUrl = loginOrigin.replaceFirst(RegExp(r'/+$'), '');
    final cleanBasePath = basePath.startsWith('/') ? basePath : '/$basePath';
    return '$cleanBaseUrl${cleanBasePath.replaceFirst(RegExp(r'/+$'), '')}/auth/login-redirect';
  }
}
