typedef JsonMap = Map<String, dynamic>;

const Object _sentinel = Object();

JsonMap _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<T> _list<T>(Object? value, T Function(Object? item) parse) {
  if (value is List) {
    return value.map(parse).toList(growable: false);
  }
  return <T>[];
}

String _string(Object? value, [String fallback = '']) {
  return value?.toString() ?? fallback;
}

String? _nullableString(Object? value) {
  return value?.toString();
}

bool _bool(Object? value, [bool fallback = false]) {
  return value is bool ? value : fallback;
}

num _num(Object? value, [num fallback = 0]) {
  if (value is num) {
    return value;
  }
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}

int _int(Object? value, [int fallback = 0]) {
  return _num(value, fallback).toInt();
}

double _double(Object? value, [double fallback = 0]) {
  return _num(value, fallback).toDouble();
}

DateTime _date(Object? value) {
  return _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

String _dateToJson(DateTime value) {
  return value.toUtc().toIso8601String();
}

String? _nullableDateToJson(DateTime? value) {
  return value == null ? null : _dateToJson(value);
}

List<String> _stringList(Object? value) {
  return _list(value, _string);
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.title,
    required this.timezone,
    required this.avatarUrl,
    required this.isActive,
    required this.isSuperAdmin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Object? json) {
    final data = _map(json);
    return User(
      id: _string(data['id']),
      email: _string(data['email']),
      name: _string(data['name']),
      title: _string(data['title']),
      timezone: _string(data['timezone']),
      avatarUrl: _nullableString(data['avatar_url']),
      isActive: _bool(data['is_active']),
      isSuperAdmin: _bool(data['is_super_admin']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }

  final String id;
  final String email;
  final String name;
  final String title;
  final String timezone;
  final String? avatarUrl;
  final bool isActive;
  final bool isSuperAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'title': title,
    'timezone': timezone,
    'avatar_url': avatarUrl,
    'is_active': isActive,
    'is_super_admin': isSuperAdmin,
    'created_at': _dateToJson(createdAt),
    'updated_at': _dateToJson(updatedAt),
  };
}

class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.inviteCode,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tenant.fromJson(Object? json) {
    final data = _map(json);
    return Tenant(
      id: _string(data['id']),
      name: _string(data['name']),
      slug: _string(data['slug']),
      inviteCode: _string(data['invite_code']),
      settings: _map(data['settings']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }

  final String id;
  final String name;
  final String slug;
  final String inviteCode;
  final JsonMap settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'invite_code': inviteCode,
    'settings': settings,
    'created_at': _dateToJson(createdAt),
    'updated_at': _dateToJson(updatedAt),
  };
}

class TenantPreview {
  const TenantPreview({
    required this.id,
    required this.name,
    required this.alreadyMember,
  });

  factory TenantPreview.fromJson(Object? json) {
    final data = _map(json);
    return TenantPreview(
      id: _string(data['id']),
      name: _string(data['name']),
      alreadyMember: _bool(data['already_member']),
    );
  }

  final String id;
  final String name;
  final bool alreadyMember;

  JsonMap toJson() => {'id': id, 'name': name, 'already_member': alreadyMember};
}

class TenantJoinResult {
  const TenantJoinResult({required this.tenantId, required this.joined});

  factory TenantJoinResult.fromJson(Object? json) {
    final data = _map(json);
    return TenantJoinResult(
      tenantId: _string(data['tenant_id']),
      joined: _bool(data['joined']),
    );
  }

  final String tenantId;
  final bool joined;

  JsonMap toJson() => {'tenant_id': tenantId, 'joined': joined};
}

class JoinByInviteResult {
  const JoinByInviteResult({
    required this.tenantId,
    required this.projectId,
    required this.projectName,
    required this.alreadyMember,
  });

  factory JoinByInviteResult.fromJson(Object? json) {
    final data = _map(json);
    return JoinByInviteResult(
      tenantId: _string(data['tenant_id']),
      projectId: _string(data['project_id']),
      projectName: _string(data['project_name']),
      alreadyMember: _bool(data['already_member']),
    );
  }

  final String tenantId;
  final String projectId;
  final String projectName;
  final bool alreadyMember;

  JsonMap toJson() => {
    'tenant_id': tenantId,
    'project_id': projectId,
    'project_name': projectName,
    'already_member': alreadyMember,
  };
}

class Project {
  const Project({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.code,
    required this.inviteCode,
    required this.accentColor,
    required this.icon,
    required this.description,
    required this.checkinTime,
    required this.checkinTimezone,
    required this.digestDelayMinutes,
    required this.isArchived,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Object? json) {
    final data = _map(json);
    return Project(
      id: _string(data['id']),
      tenantId: _string(data['tenant_id']),
      name: _string(data['name']),
      code: _string(data['code']),
      inviteCode: _string(data['invite_code']),
      accentColor: _string(data['accent_color']),
      icon: _nullableString(data['icon']),
      description: _string(data['description']),
      checkinTime: _string(data['checkin_time']),
      checkinTimezone: _string(data['checkin_timezone']),
      digestDelayMinutes: _int(data['digest_delay_minutes'], 60),
      isArchived: _bool(data['is_archived']),
      createdBy: _string(data['created_by']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }

  final String id;
  final String tenantId;
  final String name;
  final String code;
  final String inviteCode;
  final String accentColor;
  final String? icon;
  final String description;
  final String checkinTime;
  final String checkinTimezone;
  final int digestDelayMinutes;
  final bool isArchived;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name,
    'code': code,
    'invite_code': inviteCode,
    'accent_color': accentColor,
    'icon': icon,
    'description': description,
    'checkin_time': checkinTime,
    'checkin_timezone': checkinTimezone,
    'digest_delay_minutes': digestDelayMinutes,
    'is_archived': isArchived,
    'created_by': createdBy,
    'created_at': _dateToJson(createdAt),
    'updated_at': _dateToJson(updatedAt),
  };
}

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.role,
    required this.checkinEnabled,
    required this.createdAt,
    this.user,
  });

  factory ProjectMember.fromJson(Object? json) {
    final data = _map(json);
    return ProjectMember(
      id: _string(data['id']),
      projectId: _string(data['project_id']),
      userId: _string(data['user_id']),
      role: _string(data['role']),
      checkinEnabled: _bool(data['checkin_enabled'], true),
      createdAt: _date(data['created_at']),
      user: data.containsKey('user') && data['user'] != null
          ? User.fromJson(data['user'])
          : null,
    );
  }

  final String id;
  final String projectId;
  final String userId;
  final String role;
  final bool checkinEnabled;
  final DateTime createdAt;
  final User? user;

  JsonMap toJson() => {
    'id': id,
    'project_id': projectId,
    'user_id': userId,
    'role': role,
    'checkin_enabled': checkinEnabled,
    'created_at': _dateToJson(createdAt),
    if (user != null) 'user': user!.toJson(),
  };
}

class ProjectWithMembers extends Project {
  const ProjectWithMembers({
    required super.id,
    required super.tenantId,
    required super.name,
    required super.code,
    required super.inviteCode,
    required super.accentColor,
    required super.icon,
    required super.description,
    required super.checkinTime,
    required super.checkinTimezone,
    required super.digestDelayMinutes,
    required super.isArchived,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
    required this.members,
  });

  factory ProjectWithMembers.fromJson(Object? json) {
    final project = Project.fromJson(json);
    final data = _map(json);
    return ProjectWithMembers(
      id: project.id,
      tenantId: project.tenantId,
      name: project.name,
      code: project.code,
      inviteCode: project.inviteCode,
      accentColor: project.accentColor,
      icon: project.icon,
      description: project.description,
      checkinTime: project.checkinTime,
      checkinTimezone: project.checkinTimezone,
      digestDelayMinutes: project.digestDelayMinutes,
      isArchived: project.isArchived,
      createdBy: project.createdBy,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      members: _list(data['members'], ProjectMember.fromJson),
    );
  }

  final List<ProjectMember> members;

  @override
  JsonMap toJson() => {
    ...super.toJson(),
    'members': members.map((member) => member.toJson()).toList(),
  };
}

class ProjectMemberPreview {
  const ProjectMemberPreview({required this.name, required this.avatarUrl});

  factory ProjectMemberPreview.fromJson(Object? json) {
    final data = _map(json);
    return ProjectMemberPreview(
      name: _string(data['name']),
      avatarUrl: _nullableString(data['avatar_url']),
    );
  }

  final String name;
  final String? avatarUrl;

  JsonMap toJson() => {'name': name, 'avatar_url': avatarUrl};
}

class ProjectListItem extends Project {
  const ProjectListItem({
    required super.id,
    required super.tenantId,
    required super.name,
    required super.code,
    required super.inviteCode,
    required super.accentColor,
    required super.icon,
    required super.description,
    required super.checkinTime,
    required super.checkinTimezone,
    required super.digestDelayMinutes,
    required super.isArchived,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
    required this.memberCount,
    required this.lastMessagePreview,
    required this.lastMessageTs,
    required this.memberPreviews,
    required this.blockerCount,
  });

  factory ProjectListItem.fromJson(Object? json) {
    final project = Project.fromJson(json);
    final data = _map(json);
    return ProjectListItem(
      id: project.id,
      tenantId: project.tenantId,
      name: project.name,
      code: project.code,
      inviteCode: project.inviteCode,
      accentColor: project.accentColor,
      icon: project.icon,
      description: project.description,
      checkinTime: project.checkinTime,
      checkinTimezone: project.checkinTimezone,
      digestDelayMinutes: project.digestDelayMinutes,
      isArchived: project.isArchived,
      createdBy: project.createdBy,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      memberCount: _int(data['member_count']),
      lastMessagePreview: _nullableString(data['last_message_preview']),
      lastMessageTs: _nullableDate(data['last_message_ts']),
      memberPreviews: _list(
        data['member_previews'],
        ProjectMemberPreview.fromJson,
      ),
      blockerCount: _int(data['blocker_count']),
    );
  }

  final int memberCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageTs;
  final List<ProjectMemberPreview> memberPreviews;
  final int blockerCount;

  @override
  JsonMap toJson() => {
    ...super.toJson(),
    'member_count': memberCount,
    'last_message_preview': lastMessagePreview,
    'last_message_ts': _nullableDateToJson(lastMessageTs),
    'member_previews': memberPreviews.map((item) => item.toJson()).toList(),
    'blocker_count': blockerCount,
  };
}

class Thread {
  const Thread({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Thread.fromJson(Object? json) {
    final data = _map(json);
    return Thread(
      id: _string(data['id']),
      projectId: _string(data['project_id']),
      userId: _string(data['user_id']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }

  final String id;
  final String projectId;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'project_id': projectId,
    'user_id': userId,
    'created_at': _dateToJson(createdAt),
    'updated_at': _dateToJson(updatedAt),
  };
}

class Recipient {
  const Recipient({required this.kind, this.userId});

  factory Recipient.fromJson(Object? json) {
    final data = _map(json);
    return Recipient(
      kind: _string(data['kind']),
      userId: _nullableString(data['user_id']),
    );
  }

  final String kind;
  final String? userId;

  JsonMap toJson() => {'kind': kind, if (userId != null) 'user_id': userId};
}

class ReplyPreview {
  const ReplyPreview({
    required this.id,
    required this.bodySnippet,
    required this.fromUserId,
    required this.toUserId,
  });

  factory ReplyPreview.fromJson(Object? json) {
    final data = _map(json);
    return ReplyPreview(
      id: _string(data['id']),
      bodySnippet: _string(data['body_snippet']),
      fromUserId: _nullableString(data['from_user_id']),
      toUserId: _nullableString(data['to_user_id']),
    );
  }

  final String id;
  final String bodySnippet;
  final String? fromUserId;
  final String? toUserId;

  JsonMap toJson() => {
    'id': id,
    'body_snippet': bodySnippet,
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
  };
}

class Message {
  const Message({
    required this.id,
    required this.threadId,
    required this.type,
    required this.body,
    required this.tone,
    required this.fromUserId,
    required this.toUserId,
    required this.toAudience,
    required this.recipient,
    required this.repliesToMessageId,
    required this.replyToPreview,
    required this.originalText,
    required this.extra,
    required this.promptVersionId,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory Message.fromJson(Object? json) {
    final data = _map(json);
    return Message(
      id: _string(data['id']),
      threadId: _string(data['thread_id']),
      type: _string(data['type']),
      body: _nullableString(data['body']),
      tone: _nullableString(data['tone']),
      fromUserId: _nullableString(data['from_user_id']),
      toUserId: _nullableString(data['to_user_id']),
      toAudience: _nullableString(data['to_audience']),
      recipient: data['recipient'] == null
          ? null
          : Recipient.fromJson(data['recipient']),
      repliesToMessageId: _nullableString(data['replies_to_message_id']),
      replyToPreview: data['reply_to_preview'] == null
          ? null
          : ReplyPreview.fromJson(data['reply_to_preview']),
      originalText: _nullableString(data['original_text']),
      extra: data['extra'] == null ? null : _map(data['extra']),
      promptVersionId: _nullableString(data['prompt_version_id']),
      createdAt: _date(data['created_at']),
      resolvedAt: _nullableDate(data['resolved_at']),
    );
  }

  final String id;
  final String threadId;
  final String type;
  final String? body;
  final String? tone;
  final String? fromUserId;
  final String? toUserId;
  final String? toAudience;
  final Recipient? recipient;
  final String? repliesToMessageId;
  final ReplyPreview? replyToPreview;
  final String? originalText;
  final JsonMap? extra;
  final String? promptVersionId;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Message copyWith({
    String? id,
    String? threadId,
    String? type,
    Object? body = _sentinel,
    Object? tone = _sentinel,
    Object? fromUserId = _sentinel,
    Object? toUserId = _sentinel,
    Object? toAudience = _sentinel,
    Object? recipient = _sentinel,
    Object? repliesToMessageId = _sentinel,
    Object? replyToPreview = _sentinel,
    Object? originalText = _sentinel,
    Object? extra = _sentinel,
    Object? promptVersionId = _sentinel,
    DateTime? createdAt,
    Object? resolvedAt = _sentinel,
  }) {
    return Message(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      type: type ?? this.type,
      body: body == _sentinel ? this.body : body as String?,
      tone: tone == _sentinel ? this.tone : tone as String?,
      fromUserId: fromUserId == _sentinel
          ? this.fromUserId
          : fromUserId as String?,
      toUserId: toUserId == _sentinel ? this.toUserId : toUserId as String?,
      toAudience: toAudience == _sentinel
          ? this.toAudience
          : toAudience as String?,
      recipient: recipient == _sentinel
          ? this.recipient
          : recipient as Recipient?,
      repliesToMessageId: repliesToMessageId == _sentinel
          ? this.repliesToMessageId
          : repliesToMessageId as String?,
      replyToPreview: replyToPreview == _sentinel
          ? this.replyToPreview
          : replyToPreview as ReplyPreview?,
      originalText: originalText == _sentinel
          ? this.originalText
          : originalText as String?,
      extra: extra == _sentinel ? this.extra : extra as JsonMap?,
      promptVersionId: promptVersionId == _sentinel
          ? this.promptVersionId
          : promptVersionId as String?,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt == _sentinel
          ? this.resolvedAt
          : resolvedAt as DateTime?,
    );
  }

  JsonMap toJson() => {
    'id': id,
    'thread_id': threadId,
    'type': type,
    'body': body,
    'tone': tone,
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'to_audience': toAudience,
    'recipient': recipient?.toJson(),
    'replies_to_message_id': repliesToMessageId,
    'reply_to_preview': replyToPreview?.toJson(),
    'original_text': originalText,
    'extra': extra,
    'prompt_version_id': promptVersionId,
    'created_at': _dateToJson(createdAt),
    'resolved_at': _nullableDateToJson(resolvedAt),
  };
}

class SseMessage {
  const SseMessage({
    required this.id,
    required this.threadId,
    required this.type,
    required this.body,
    required this.tone,
    required this.fromUserId,
    required this.toUserId,
    required this.toAudience,
    required this.repliesToMessageId,
    required this.originalText,
    required this.extra,
    required this.createdAt,
  });

  factory SseMessage.fromJson(Object? json) {
    final data = _map(json);
    return SseMessage(
      id: _string(data['id']),
      threadId: _nullableString(data['thread_id']),
      type: _string(data['type']),
      body: _nullableString(data['body']),
      tone: _nullableString(data['tone']),
      fromUserId: _nullableString(data['from_user_id']),
      toUserId: _nullableString(data['to_user_id']),
      toAudience: _nullableString(data['to_audience']),
      repliesToMessageId: _nullableString(data['replies_to_message_id']),
      originalText: _nullableString(data['original_text']),
      extra: data['extra'] == null ? null : _map(data['extra']),
      createdAt: _date(data['created_at']),
    );
  }

  final String id;
  final String? threadId;
  final String type;
  final String? body;
  final String? tone;
  final String? fromUserId;
  final String? toUserId;
  final String? toAudience;
  final String? repliesToMessageId;
  final String? originalText;
  final JsonMap? extra;
  final DateTime createdAt;

  JsonMap toJson() => {
    'id': id,
    'thread_id': threadId,
    'type': type,
    'body': body,
    'tone': tone,
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'to_audience': toAudience,
    'replies_to_message_id': repliesToMessageId,
    'original_text': originalText,
    'extra': extra,
    'created_at': _dateToJson(createdAt),
  };
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.fromUserId,
    required this.relevance,
  });

  factory SearchResult.fromJson(Object? json) {
    final data = _map(json);
    return SearchResult(
      id: _string(data['id']),
      body: _string(data['body']),
      type: _string(data['type']),
      createdAt: _date(data['created_at']),
      fromUserId: _nullableString(data['from_user_id']),
      relevance: _double(data['relevance']),
    );
  }

  final String id;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? fromUserId;
  final double relevance;

  JsonMap toJson() => {
    'id': id,
    'body': body,
    'type': type,
    'created_at': _dateToJson(createdAt),
    'from_user_id': fromUserId,
    'relevance': relevance,
  };
}

class SearchResponse {
  const SearchResponse({required this.results, required this.count});

  factory SearchResponse.fromJson(Object? json) {
    final data = _map(json);
    return SearchResponse(
      results: _list(data['results'], SearchResult.fromJson),
      count: _int(data['count']),
    );
  }

  final List<SearchResult> results;
  final int count;

  JsonMap toJson() => {
    'results': results.map((result) => result.toJson()).toList(),
    'count': count,
  };
}

class TenantMembership {
  const TenantMembership({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.user,
  });

  factory TenantMembership.fromJson(Object? json) {
    final data = _map(json);
    return TenantMembership(
      id: _string(data['id']),
      tenantId: _string(data['tenant_id']),
      userId: _string(data['user_id']),
      role: _string(data['role']),
      createdAt: _date(data['created_at']),
      user: User.fromJson(data['user']),
    );
  }

  final String id;
  final String tenantId;
  final String userId;
  final String role;
  final DateTime createdAt;
  final User user;

  JsonMap toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'user_id': userId,
    'role': role,
    'created_at': _dateToJson(createdAt),
    'user': user.toJson(),
  };
}

class MemberStatus {
  const MemberStatus({
    required this.userId,
    required this.user,
    required this.role,
    required this.checkedIn,
    required this.hasBlocker,
    required this.relayCount,
    required this.blockerCount,
    required this.relaysWithYou,
    required this.lastActive,
  });

  factory MemberStatus.fromJson(Object? json) {
    final data = _map(json);
    return MemberStatus(
      userId: _string(data['user_id']),
      user: User.fromJson(data['user']),
      role: _string(data['role']),
      checkedIn: _bool(data['checked_in']),
      hasBlocker: _bool(data['has_blocker']),
      relayCount: _int(data['relay_count']),
      blockerCount: _int(data['blocker_count']),
      relaysWithYou: _int(data['relays_with_you']),
      lastActive: _nullableDate(data['last_active']),
    );
  }

  final String userId;
  final User user;
  final String role;
  final bool checkedIn;
  final bool hasBlocker;
  final int relayCount;
  final int blockerCount;
  final int relaysWithYou;
  final DateTime? lastActive;

  JsonMap toJson() => {
    'user_id': userId,
    'user': user.toJson(),
    'role': role,
    'checked_in': checkedIn,
    'has_blocker': hasBlocker,
    'relay_count': relayCount,
    'blocker_count': blockerCount,
    'relays_with_you': relaysWithYou,
    'last_active': _nullableDateToJson(lastActive),
  };
}

class ProjectGoals {
  const ProjectGoals({
    required this.projectId,
    required this.revision,
    required this.goals,
    required this.changedBy,
    required this.changedAt,
  });

  factory ProjectGoals.fromJson(Object? json) {
    final data = _map(json);
    return ProjectGoals(
      projectId: _string(data['project_id']),
      revision: data['revision'] == null ? null : _int(data['revision']),
      goals: _stringList(data['goals']),
      changedBy: _nullableString(data['changed_by']),
      changedAt: _nullableDate(data['changed_at']),
    );
  }

  final String projectId;
  final int? revision;
  final List<String> goals;
  final String? changedBy;
  final DateTime? changedAt;

  JsonMap toJson() => {
    'project_id': projectId,
    'revision': revision,
    'goals': goals,
    'changed_by': changedBy,
    'changed_at': _nullableDateToJson(changedAt),
  };
}

class ProjectGoalsHistoryItem {
  const ProjectGoalsHistoryItem({
    required this.revision,
    required this.goals,
    required this.changedByName,
    required this.changedAt,
  });

  factory ProjectGoalsHistoryItem.fromJson(Object? json) {
    final data = _map(json);
    return ProjectGoalsHistoryItem(
      revision: _int(data['revision']),
      goals: _stringList(data['goals']),
      changedByName: _nullableString(data['changed_by_name']),
      changedAt: _date(data['changed_at']),
    );
  }

  final int revision;
  final List<String> goals;
  final String? changedByName;
  final DateTime changedAt;

  JsonMap toJson() => {
    'revision': revision,
    'goals': goals,
    'changed_by_name': changedByName,
    'changed_at': _dateToJson(changedAt),
  };
}

class ProjectState {
  const ProjectState({
    required this.projectId,
    required this.revision,
    required this.body,
    required this.changedBy,
    required this.changedAt,
  });

  factory ProjectState.fromJson(Object? json) {
    final data = _map(json);
    return ProjectState(
      projectId: _string(data['project_id']),
      revision: data['revision'] == null ? null : _int(data['revision']),
      body: _nullableString(data['body']),
      changedBy: _nullableString(data['changed_by']),
      changedAt: _nullableDate(data['changed_at']),
    );
  }

  final String projectId;
  final int? revision;
  final String? body;
  final String? changedBy;
  final DateTime? changedAt;

  JsonMap toJson() => {
    'project_id': projectId,
    'revision': revision,
    'body': body,
    'changed_by': changedBy,
    'changed_at': _nullableDateToJson(changedAt),
  };
}

class ProjectStateHistoryItem {
  const ProjectStateHistoryItem({
    required this.revision,
    required this.body,
    required this.changedByName,
    required this.changedAt,
    required this.autoEvolved,
  });

  factory ProjectStateHistoryItem.fromJson(Object? json) {
    final data = _map(json);
    return ProjectStateHistoryItem(
      revision: _int(data['revision']),
      body: _string(data['body']),
      changedByName: _nullableString(data['changed_by_name']),
      changedAt: _date(data['changed_at']),
      autoEvolved: _bool(data['auto_evolved']),
    );
  }

  final int revision;
  final String body;
  final String? changedByName;
  final DateTime changedAt;
  final bool autoEvolved;

  JsonMap toJson() => {
    'revision': revision,
    'body': body,
    'changed_by_name': changedByName,
    'changed_at': _dateToJson(changedAt),
    'auto_evolved': autoEvolved,
  };
}

class ProjectSheet {
  const ProjectSheet({
    required this.id,
    required this.googleSheetId,
    required this.label,
    required this.schemaHint,
    required this.attachedBy,
    required this.createdAt,
  });

  factory ProjectSheet.fromJson(Object? json) {
    final data = _map(json);
    return ProjectSheet(
      id: _string(data['id']),
      googleSheetId: _string(data['google_sheet_id']),
      label: _string(data['label']),
      schemaHint: _string(data['schema_hint']),
      attachedBy: _nullableString(data['attached_by']),
      createdAt: _date(data['created_at']),
    );
  }

  final String id;
  final String googleSheetId;
  final String label;
  final String schemaHint;
  final String? attachedBy;
  final DateTime createdAt;

  JsonMap toJson() => {
    'id': id,
    'google_sheet_id': googleSheetId,
    'label': label,
    'schema_hint': schemaHint,
    'attached_by': attachedBy,
    'created_at': _dateToJson(createdAt),
  };
}

class GoogleSheetsStatus {
  const GoogleSheetsStatus({required this.connected, required this.scopes});

  factory GoogleSheetsStatus.fromJson(Object? json) {
    final data = _map(json);
    return GoogleSheetsStatus(
      connected: _bool(data['connected']),
      scopes: _stringList(data['scopes']),
    );
  }

  final bool connected;
  final List<String> scopes;

  JsonMap toJson() => {'connected': connected, 'scopes': scopes};
}
