class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.basePath,
    required this.timeout,
  });

  static const defaultConfig = ApiConfig(
    baseUrl: String.fromEnvironment(
      'MAIA_API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    ),
    basePath: String.fromEnvironment(
      'MAIA_API_BASE_PATH',
      defaultValue: '/api/v1',
    ),
    timeout: Duration(seconds: 30),
  );

  final String baseUrl;
  final String basePath;
  final Duration timeout;

  String get normalizedBaseUrl {
    final cleanBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final cleanBasePath = basePath.startsWith('/') ? basePath : '/$basePath';
    return '$cleanBaseUrl${cleanBasePath.replaceFirst(RegExp(r'/+$'), '')}';
  }
}
