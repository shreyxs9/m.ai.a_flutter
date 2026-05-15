import 'package:shared_preferences/shared_preferences.dart';

class ApiSessionStore {
  const ApiSessionStore();

  static const tokenKey = 'maia_token';
  static const tenantIdKey = 'maia_tenant_id';

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
}
