import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../network/network.dart';
import 'browser_url.dart';

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
      activeTenant:
          clearActiveTenant ? null : activeTenant ?? this.activeTenant,
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

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  late final ApiSessionStore _sessionStore;
  late final AuthService _authService;
  late final TenantService _tenantService;

  @override
  Future<AuthState> build() async {
    _sessionStore = ref.watch(apiSessionStoreProvider);
    _authService = ref.watch(authServiceProvider);
    _tenantService = ref.watch(tenantServiceProvider);

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
      await _sessionStore.clear();
      return AuthState(
        loading: false,
        error: _messageFor(error),
      );
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
        state = state.whenData((auth) => auth.copyWith(error: _messageFor(error)));
      }
      rethrow;
    }
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
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return;
    }

    await _sessionStore.setToken(token);

    final replayed = await _replayPendingInvite();
    if (!replayed) {
      final cleanUri = uri.replace(queryParameters: <String, String>{});
      final cleanPath = cleanUri.hasFragment && cleanUri.fragment.isNotEmpty
          ? '${cleanUri.path}#${cleanUri.fragment}'
          : cleanUri.path.isEmpty
              ? '/'
              : cleanUri.path;
      replaceBrowserUrl(cleanPath);
    }
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
      await _authService.updateTimezone(DateTime.now().timeZoneName);
    } catch (_) {
      // Timezone sync is non-critical and should not invalidate the session.
    }
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
    return error is ApiException &&
        (error.status == 401 || error.status == 403 || error.status == null);
  }

  String _messageFor(Object error) {
    if (error is ApiException && error.message.isNotEmpty) {
      return error.message;
    }
    return 'Session expired. Please sign in again.';
  }
}
