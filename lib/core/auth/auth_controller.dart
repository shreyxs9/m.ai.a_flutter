import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../network/network.dart';
import 'browser_url.dart';
import 'timezone_detector.dart';

@immutable
class AuthState {
  const AuthState({
    this.user,
    this.tenants = const <Tenant>[],
    this.activeTenant,
    this.loading = true,
    this.error,
  });

  final User? user;
  final List<Tenant> tenants;
  final Tenant? activeTenant;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    List<Tenant>? tenants,
    Tenant? activeTenant,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearActiveTenant = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      tenants: tenants ?? this.tenants,
      activeTenant: clearActiveTenant
          ? null
          : activeTenant ?? this.activeTenant,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final apiSessionStoreProvider = Provider<ApiSessionStore>((ref) {
  return const ApiSessionStore();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(sessionStore: ref.watch(apiSessionStoreProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

final tenantServiceProvider = Provider<TenantService>((ref) {
  return TenantService(ref.watch(apiClientProvider));
});

final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(ref.watch(apiClientProvider));
});

final threadServiceProvider = Provider<ThreadService>((ref) {
  return ThreadService(ref.watch(apiClientProvider));
});

final messageServiceProvider = Provider<MessageService>((ref) {
  return MessageService(ref.watch(apiClientProvider));
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(ref.watch(apiClientProvider));
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(apiClientProvider));
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(apiClientProvider));
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.watch(apiClientProvider));
});

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.watch(apiClientProvider));
});

final schedulerServiceProvider = Provider<SchedulerService>((ref) {
  return SchedulerService(ref.watch(apiClientProvider));
});

final chatTransportServiceProvider = Provider<ChatTransportService>((ref) {
  return ChatTransportService(ref.watch(apiClientProvider));
});

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  late final ApiSessionStore _sessionStore;
  late final AuthService _authService;
  late final TenantService _tenantService;
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  Future<AuthState> build() async {
    _sessionStore = ref.watch(apiSessionStoreProvider);
    _authService = ref.watch(authServiceProvider);
    _tenantService = ref.watch(tenantServiceProvider);
    _listenForAuthDeepLinks();

    return _bootstrap();
  }

  Future<AuthState> _bootstrap() async {
    await _captureTokenFromUrl();

    final token = await _sessionStore.getToken();
    if (token == null || token.isEmpty) {
      return const AuthState(loading: false);
    }

    try {
      final user = await _authService.getMe();
      final tenantList = await _tenantService.list();

      final savedTenantId = await _sessionStore.getTenantId();
      final activeTenant = _chooseTenant(tenantList, savedTenantId);
      if (activeTenant != null) {
        await _sessionStore.setTenantId(activeTenant.id);
      }

      unawaited(_syncTimezone());

      return AuthState(
        user: user,
        tenants: tenantList,
        activeTenant: activeTenant,
        loading: false,
      );
    } catch (error) {
      if (_isSessionFailure(error)) {
        await _sessionStore.clear();
      }
      return AuthState(loading: false, error: _messageFor(error));
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_bootstrap);
  }

  Future<void> logout() async {
    await _sessionStore.clear();
    state = const AsyncData(AuthState(loading: false));
  }

  Future<void> signInWithBrokeredOAuth(
    Future<void> Function(Uri url) openAuthUrl,
  ) async {
    state = AsyncData(
      (state.asData?.value ?? const AuthState()).copyWith(
        loading: true,
        clearError: true,
      ),
    );

    try {
      final verifier = _createPkceVerifier();
      final session = await _authService.startLoginSession(
        _createPkceChallenge(verifier),
      );
      final authUri = Uri.parse(session.url);
      if (!authUri.hasScheme || session.sessionId.isEmpty) {
        throw const ApiException(
          null,
          'Google sign in did not return a valid authorization URL.',
        );
      }
      await openAuthUrl(authUri);
      final token = await _pollLoginSession(session, verifier);
      await _sessionStore.setToken(token);
      state = await AsyncValue.guard(_bootstrap);
    } catch (error) {
      state = AsyncData(AuthState(loading: false, error: _messageFor(error)));
    }
  }

  Future<void> switchTenant(Tenant tenant) async {
    await _sessionStore.setTenantId(tenant.id);
    state = state.whenData((auth) {
      return auth.copyWith(activeTenant: tenant, clearError: true);
    });
  }

  Future<List<Tenant>> refreshTenants() async {
    try {
      final tenantList = await _tenantService.list();
      final current = state.asData?.value;
      final activeTenant = _chooseTenant(
        tenantList,
        current?.activeTenant?.id ?? await _sessionStore.getTenantId(),
      );
      if (activeTenant != null) {
        await _sessionStore.setTenantId(activeTenant.id);
      }
      state = AsyncData(
        (current ?? const AuthState(loading: false)).copyWith(
          tenants: tenantList,
          activeTenant: activeTenant,
          clearActiveTenant: activeTenant == null,
          clearError: true,
        ),
      );
      return tenantList;
    } catch (error) {
      if (_isSessionFailure(error)) {
        await _sessionStore.clear();
        state = AsyncData(AuthState(loading: false, error: _messageFor(error)));
      } else {
        state = state.whenData(
          (auth) => auth.copyWith(error: _messageFor(error)),
        );
      }
      rethrow;
    }
  }

  Future<void> updateUser(User user) async {
    state = state.whenData(
      (auth) => auth.copyWith(user: user, clearError: true),
    );
  }

  Future<User?> updateTitle(String title) async {
    final user = await ref.read(authServiceProvider).updateTitle(title);
    if (user != null) {
      await updateUser(user);
    }
    return user;
  }

  Future<void> selectTenantId(String tenantId) async {
    await _sessionStore.setTenantId(tenantId);
    final current = state.asData?.value;
    Tenant? activeTenant;
    for (final tenant in current?.tenants ?? const <Tenant>[]) {
      if (tenant.id == tenantId) {
        activeTenant = tenant;
        break;
      }
    }
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          activeTenant: activeTenant,
          clearActiveTenant: activeTenant == null,
          clearError: true,
        ),
      );
    }
  }

  Future<void> _captureTokenFromUrl() async {
    final uri = currentBrowserUri();
    final browserCapture = await _captureTokenFromUri(uri);
    if (browserCapture.captured && !browserCapture.replayedInvite) {
      final cleanUri = uri.replace(queryParameters: <String, String>{});
      final cleanPath = cleanUri.hasFragment && cleanUri.fragment.isNotEmpty
          ? '${cleanUri.path}#${cleanUri.fragment}'
          : cleanUri.path.isEmpty
          ? '/'
          : cleanUri.path;
      replaceBrowserUrl(cleanPath);
      return;
    }
    if (browserCapture.captured) {
      return;
    }

    if (kIsWeb) {
      return;
    }

    final initialLink = await AppLinks().getInitialLink().timeout(
      const Duration(milliseconds: 250),
      onTimeout: () => null,
    );
    if (initialLink != null) {
      await _captureTokenFromUri(initialLink);
    }
  }

  Future<_TokenCaptureResult> _captureTokenFromUri(Uri uri) async {
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return const _TokenCaptureResult(captured: false);
    }

    await _sessionStore.setToken(token);

    final replayed = await _replayPendingInvite();
    return _TokenCaptureResult(captured: true, replayedInvite: replayed);
  }

  void _listenForAuthDeepLinks() {
    if (kIsWeb || _deepLinkSubscription != null) {
      return;
    }
    final appLinks = AppLinks();
    _deepLinkSubscription = appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleAuthDeepLink(uri));
    });
    ref.onDispose(() {
      unawaited(_deepLinkSubscription?.cancel());
      _deepLinkSubscription = null;
    });
  }

  Future<void> _handleAuthDeepLink(Uri uri) async {
    final result = await _captureTokenFromUri(uri);
    if (!result.captured) {
      return;
    }
    await reload();
  }

  Future<bool> _replayPendingInvite() async {
    final pendingWorkspace = await _sessionStore.getPendingWorkspaceInvite();
    final pendingProject = await _sessionStore.getPendingInvite();
    if (pendingWorkspace == null && pendingProject == null) {
      return false;
    }

    await _sessionStore.clearPendingInvites();
    final path = pendingWorkspace != null
        ? '/join-workspace/$pendingWorkspace'
        : '/join/$pendingProject';
    replaceBrowserUrl(path);
    return true;
  }

  Future<void> _syncTimezone() async {
    try {
      await _authService.updateTimezone(detectTimezone());
    } catch (_) {
      // Timezone sync is non-critical and should not invalidate the session.
    }
  }

  Future<String> _pollLoginSession(
    LoginSessionStartResult session,
    String verifier,
  ) async {
    final intervalSeconds = max(1, session.interval);
    final deadline = DateTime.now().add(Duration(seconds: session.expiresIn));

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: intervalSeconds));
      final result = await _authService.pollLoginSession(
        session.sessionId,
        verifier,
      );
      final token = result.token;
      if (result.isComplete && token != null && token.isNotEmpty) {
        return token;
      }
    }

    throw const ApiException(
      null,
      'Google sign in expired. Please start sign in again.',
    );
  }

  String _createPkceVerifier() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(64, (_) => random.nextInt(256)),
    );
    return _base64UrlNoPadding(bytes);
  }

  String _createPkceChallenge(String verifier) {
    return _base64UrlNoPadding(
      Uint8List.fromList(sha256.convert(utf8.encode(verifier)).bytes),
    );
  }

  String _base64UrlNoPadding(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Tenant? _chooseTenant(List<Tenant> tenants, String? tenantId) {
    if (tenants.isEmpty) {
      return null;
    }
    for (final tenant in tenants) {
      if (tenant.id == tenantId) {
        return tenant;
      }
    }
    return tenants.first;
  }

  bool _isSessionFailure(Object error) {
    return error is ApiException && error.status == 401;
  }

  String _messageFor(Object error) {
    if (error is ApiException && error.message.isNotEmpty) {
      return error.message;
    }
    final message = error.toString().trim();
    if (message.isNotEmpty && message != 'null') {
      return message;
    }
    return 'Something went wrong while restoring your session. Please try again.';
  }
}

class _TokenCaptureResult {
  const _TokenCaptureResult({
    required this.captured,
    this.replayedInvite = false,
  });

  final bool captured;
  final bool replayedInvite;
}
