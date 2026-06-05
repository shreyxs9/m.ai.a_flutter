class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.basePath,
    required this.timeout,
    required this.loginOrigin,
    required this.mobileRedirectUri,
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
    mobileRedirectUri: String.fromEnvironment(
      'MAIA_MOBILE_REDIRECT_URI',
      defaultValue: 'maia://auth',
    ),
  );

  final String baseUrl;
  final String basePath;
  final Duration timeout;
  final String loginOrigin;
  final String mobileRedirectUri;

  String get normalizedBaseUrl {
    final cleanBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final cleanBasePath = basePath.startsWith('/') ? basePath : '/$basePath';
    return '$cleanBaseUrl${cleanBasePath.replaceFirst(RegExp(r'/+$'), '')}';
  }

  String loginRedirectUrl({String? redirectUri}) {
    final cleanBaseUrl = loginOrigin.replaceFirst(RegExp(r'/+$'), '');
    final cleanBasePath = basePath.startsWith('/') ? basePath : '/$basePath';
    final url =
        '$cleanBaseUrl${cleanBasePath.replaceFirst(RegExp(r'/+$'), '')}/auth/login-redirect';
    if (redirectUri == null || redirectUri.isEmpty) {
      return url;
    }
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'redirect_uri': redirectUri,
          },
        )
        .toString();
  }
}
