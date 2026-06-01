import 'package:shared_preferences/shared_preferences.dart';

class ApiSessionStore {
  const ApiSessionStore();

  static const tokenKey = 'maia_token';
  static const tenantIdKey = 'maia_tenant_id';
  static const pendingInviteKey = 'maia_pending_invite';
  static const pendingWorkspaceInviteKey = 'maia_pending_workspace_invite';

  Future<String?> getToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(tokenKey);
  }

  Future<void> setToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(tokenKey, token);
  }

  Future<String?> getTenantId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(tenantIdKey);
  }

  Future<void> setTenantId(String tenantId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(tenantIdKey, tenantId);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(tokenKey);
    await preferences.remove(tenantIdKey);
  }

  Future<void> setPendingInvite(String code) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(pendingInviteKey, code);
  }

  Future<String?> getPendingInvite() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(pendingInviteKey);
  }

  Future<void> setPendingWorkspaceInvite(String code) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(pendingWorkspaceInviteKey, code);
  }

  Future<String?> getPendingWorkspaceInvite() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(pendingWorkspaceInviteKey);
  }

  Future<void> clearPendingInvites() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(pendingInviteKey);
    await preferences.remove(pendingWorkspaceInviteKey);
  }
}
