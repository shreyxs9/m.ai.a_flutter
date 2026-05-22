import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:maia_flutter/features/chat/chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_flutter/core/network/network.dart';
import 'package:maia_flutter/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('invite code normalization', () {
    test('trims and uppercases project invite codes', () {
      expect(ProjectService.normalizeInviteCode('  abC-123  '), 'ABC-123');
    });
  });

  group('models fromJson', () {
    test(
      'ProjectListItem applies rolling-deploy defaults and parses dates',
      () {
        final item = ProjectListItem.fromJson({
          'id': 'project-1',
          'tenant_id': 'tenant-1',
          'name': 'Launch',
          'code': 'LCH',
          'accent_color': '#009688',
          'icon': null,
          'description': 'Ship the launch plan',
          'checkin_time': '09:00',
          'checkin_timezone': 'Asia/Calcutta',
          'is_archived': false,
          'created_by': 'user-1',
          'created_at': '2026-05-15T06:30:00Z',
          'updated_at': '2026-05-15T07:00:00Z',
          'member_count': 4,
          'last_message_preview': null,
          'last_message_ts': '2026-05-15T07:05:00Z',
        });

        expect(item.inviteCode, '');
        expect(item.digestDelayMinutes, 60);
        expect(item.memberPreviews, isEmpty);
        expect(item.blockerCount, 0);
        expect(item.lastMessageTs, DateTime.parse('2026-05-15T07:05:00Z'));
        expect(item.toJson()['last_message_ts'], '2026-05-15T07:05:00.000Z');
      },
    );

    test(
      'Message parses nested recipient, reply preview, nulls, and dates',
      () {
        final message = Message.fromJson({
          'id': 'message-1',
          'thread_id': 'thread-1',
          'type': 'maia_relay',
          'body': 'Can you review this?',
          'tone': 'danger',
          'from_user_id': 'user-1',
          'to_user_id': null,
          'recipient': {'kind': 'everyone'},
          'replies_to_message_id': 'message-0',
          'reply_to_preview': {
            'id': 'message-0',
            'body_snippet': 'Previous context',
            'from_user_id': null,
            'to_user_id': 'user-2',
          },
          'original_text': null,
          'extra': {'source': 'test'},
          'prompt_version_id': null,
          'created_at': '2026-05-15T08:00:00Z',
          'resolved_at': '2026-05-15T08:05:00Z',
        });

        expect(message.recipient?.kind, 'everyone');
        expect(message.replyToPreview?.bodySnippet, 'Previous context');
        expect(message.toAudience, isNull);
        expect(message.extra?['source'], 'test');
        expect(message.resolvedAt, DateTime.parse('2026-05-15T08:05:00Z'));
        expect(
          message.toJson()['reply_to_preview'],
          isA<Map<String, dynamic>>(),
        );
      },
    );

    test('MemberStatus applies numeric defaults and nullable last_active', () {
      final status = MemberStatus.fromJson({
        'user_id': 'user-1',
        'user': _userJson(),
        'role': 'member',
        'checked_in': true,
        'has_blocker': false,
        'relay_count': 2,
        'last_active': null,
      });

      expect(status.blockerCount, 0);
      expect(status.relaysWithYou, 0);
      expect(status.lastActive, isNull);
      expect(status.user.email, 'avery@example.com');
    });

    test('GoogleSheetsStatus defaults scopes to an empty list', () {
      final status = GoogleSheetsStatus.fromJson({'connected': true});

      expect(status.connected, isTrue);
      expect(status.scopes, isEmpty);
      expect(status.toJson(), {'connected': true, 'scopes': <String>[]});
    });
  });

  group('ApiException parsing', () {
    test('uses detail from JSON error bodies', () async {
      final client = ApiClient(
        dio: _dioWithResponse(
          statusCode: 400,
          body: '{"detail":"Bad invite code"}',
          contentType: Headers.jsonContentType,
        ),
      );

      await expectLater(
        client.get('/tenants/by-invite/bad'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.status, 'status', 400)
              .having((error) => error.message, 'message', 'Bad invite code'),
        ),
      );
    });

    test('uses plain text for non-JSON error bodies', () async {
      final client = ApiClient(
        dio: _dioWithResponse(
          statusCode: 429,
          body: 'Rate exceeded.',
          contentType: Headers.textPlainContentType,
        ),
      );

      await expectLater(
        client.get('/projects/'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.status, 'status', 429)
              .having((error) => error.message, 'message', 'Rate exceeded.'),
        ),
      );
    });
  });

  group('SSE streaming', () {
    test('parses event and data lines', () async {
      final frames = <SseFrame>[];
      final parser = SseLineParser();

      for (final line in [
        'event: text-delta',
        'data: {"delta":"Hel","seq":2}',
      ]) {
        final frame = parser.parseLine(line);
        if (frame != null) {
          frames.add(frame);
        }
      }

      expect(frames, hasLength(1));
      expect(frames.single.event, 'text-delta');
      expect(frames.single.data['delta'], 'Hel');
      expect(frames.single.data['seq'], 2);
    });

    test('accumulates text-delta frames in stream order', () async {
      var body = '';
      await parseSseByteStream(
        Stream<List<int>>.fromIterable([
          'event: text-start\n'
                  'data: {"stream_id":"s1","seq":1}\n'
                  'event: text-delta\n'
                  'data: {"stream_id":"s1","delta":"Hel","seq":2}\n'
                  'event: text-delta\n'
                  'data: {"stream_id":"s1","delta":"lo","seq":3}\n'
              .codeUnits,
        ]),
        (event, data) {
          if (event == 'text-start') {
            body = '';
          } else if (event == 'text-delta') {
            body += data['delta']?.toString() ?? '';
          }
        },
      );

      expect(body, 'Hello');
    });

    test('parses error frames with code and message', () async {
      final parser = SseLineParser()..parseLine('event: error');
      final frame = parser.parseLine(
        'data: {"code":"rate_limit","message":"Slow down","seq":4}',
      );

      expect(frame?.event, 'error');
      expect(frame?.data['code'], 'rate_limit');
      expect(frame?.data['message'], 'Slow down');
    });
  });

  group('pending stream persistence', () {
    test('clears expired stream sessions after four minutes', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ApiSessionStore();
      final savedAt = DateTime(2026, 5, 22, 12);
      await store.rememberPendingStream(
        threadId: 'thread-1',
        sessionId: 'session-1',
        lastSeq: 7,
        now: savedAt,
      );

      final fresh = await store.readPendingStream(
        'thread-1',
        now: savedAt.add(const Duration(minutes: 3, seconds: 59)),
      );
      expect(fresh?.sessionId, 'session-1');
      expect(fresh?.lastSeq, 7);

      final expired = await store.readPendingStream(
        'thread-1',
        now: savedAt.add(const Duration(minutes: 4, seconds: 1)),
      );
      expect(expired, isNull);
      expect(await store.readPendingStream('thread-1', now: savedAt), isNull);
    });
  });

  group('message merge', () {
    test('merges incoming messages by id and preserves order', () {
      final existing = [
        _message('m1', body: 'old', extra: {'kept': true}),
        _message('m2', body: 'second'),
      ];
      final incoming = [
        _message('m1', body: 'new'),
        _message('m3', body: 'third'),
      ];

      final merged = mergeMessagesById(existing, incoming);

      expect(merged.map((message) => message.id), ['m1', 'm2', 'm3']);
      expect(merged.first.body, 'new');
      expect(merged.first.extra, {'kept': true});
    });
  });
}

Map<String, dynamic> _userJson() => {
  'id': 'user-1',
  'email': 'avery@example.com',
  'name': 'Avery',
  'title': 'PM',
  'timezone': 'Asia/Calcutta',
  'avatar_url': null,
  'is_active': true,
  'created_at': '2026-05-15T06:00:00Z',
  'updated_at': '2026-05-15T06:10:00Z',
};

Message _message(
  String id, {
  required String body,
  Map<String, dynamic>? extra,
}) {
  return Message(
    id: id,
    threadId: 'thread-1',
    type: 'user_reply',
    body: body,
    tone: null,
    fromUserId: 'user-1',
    toUserId: null,
    toAudience: null,
    recipient: null,
    repliesToMessageId: null,
    replyToPreview: null,
    originalText: null,
    extra: extra,
    promptVersionId: null,
    createdAt: DateTime.parse('2026-05-22T12:00:00Z'),
    resolvedAt: null,
  );
}

Dio _dioWithResponse({
  required int statusCode,
  required String body,
  required String contentType,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _StaticResponseAdapter(
    statusCode: statusCode,
    body: body,
    contentType: contentType,
  );
  return dio;
}

class _StaticResponseAdapter implements HttpClientAdapter {
  const _StaticResponseAdapter({
    required this.statusCode,
    required this.body,
    required this.contentType,
  });

  final int statusCode;
  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
