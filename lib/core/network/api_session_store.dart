import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ApiSessionStore {
  const ApiSessionStore();

  static const tokenKey = 'maia_token';
  static const tenantIdKey = 'maia_tenant_id';
  static const pendingInviteKey = 'maia_pending_invite';
  static const pendingWorkspaceInviteKey = 'maia_pending_workspace_invite';
  static const pendingStreamPrefix = 'maia_pending_stream:';
  static const pendingStreamTtl = Duration(minutes: 4);

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

  Future<void> rememberPendingStream({
    required String threadId,
    required String sessionId,
    required int lastSeq,
    DateTime? now,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final savedAt = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await preferences.setString(
      '$pendingStreamPrefix$threadId',
      jsonEncode(<String, Object>{
        'sessionId': sessionId,
        'lastSeq': lastSeq,
        'savedAt': savedAt,
      }),
    );
  }

  Future<PendingStream?> readPendingStream(
    String threadId, {
    DateTime? now,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$pendingStreamPrefix$threadId';
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final sessionId = decoded['sessionId'];
      final lastSeq = decoded['lastSeq'];
      final savedAt = decoded['savedAt'];
      if (sessionId is! String || lastSeq is! num || savedAt is! num) {
        return null;
      }
      final savedAtDate = DateTime.fromMillisecondsSinceEpoch(savedAt.toInt());
      if ((now ?? DateTime.now()).difference(savedAtDate) > pendingStreamTtl) {
        await preferences.remove(key);
        return null;
      }
      return PendingStream(
        sessionId: sessionId,
        lastSeq: lastSeq.toInt(),
        savedAt: savedAtDate,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingStream(String threadId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$pendingStreamPrefix$threadId');
  }
}

class PendingStream {
  const PendingStream({
    required this.sessionId,
    required this.lastSeq,
    required this.savedAt,
  });

  final String sessionId;
  final int lastSeq;
  final DateTime savedAt;
}
