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

  group('poll-only chat transport', () {
    test('parses inference status response shape', () async {
      final client = ApiClient(
        dio: _dioWithResponse(
          statusCode: 200,
          body: '{"active":true,"session_id":"session-1"}',
          contentType: Headers.jsonContentType,
        ),
      );
      final service = ThreadService(client);

      final status = await service.getInferenceStatus('thread-1');

      expect(status.active, isTrue);
      expect(status.sessionId, 'session-1');
      expect(status.toJson(), {'active': true, 'session_id': 'session-1'});
    });

    test('parses 200 send response with maia_response', () async {
      final client = ApiClient(
        dio: _dioWithResponse(
          statusCode: 200,
          body:
              '{"session_id":"session-1","maia_response":${_messageJson('m-ai', type: 'maia_note', body: 'Got it.')}}',
          contentType: Headers.jsonContentType,
        ),
      );
      final service = ChatTransportService(client);

      final result = await service.sendMessage('thread-1', 'Progress update');

      expect(result.pending, isFalse);
      expect(result.sessionId, 'session-1');
      expect(result.maiaResponse?.id, 'm-ai');
      expect(result.maiaResponse?.body, 'Got it.');
    });

    test('parses 202 pending send response', () async {
      final client = ApiClient(
        dio: _dioWithResponse(
          statusCode: 202,
          body: '{"session_id":"session-2","pending":true}',
          contentType: Headers.jsonContentType,
        ),
      );
      final service = ChatTransportService(client);

      final result = await service.sendMessage('thread-1', 'Slow update');

      expect(result.pending, isTrue);
      expect(result.sessionId, 'session-2');
      expect(result.maiaResponse, isNull);
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

    test('updates attachment status in place by message id', () {
      final existing = [
        _message(
          'm1',
          body: 'photo',
          extra: {
            'attachments': [
              {'asset_id': 'a1', 'status': 'pending'},
            ],
          },
        ),
      ];
      final incoming = [
        _message(
          'm1',
          body: 'photo',
          extra: {
            'attachments': [
              {'asset_id': 'a1', 'status': 'ready'},
            ],
          },
        ),
      ];

      final merged = mergeMessagesById(existing, incoming);
      final attachments = merged.single.extra?['attachments'] as List<dynamic>;

      expect(merged, hasLength(1));
      expect((attachments.single as Map)['status'], 'ready');
    });
  });

  group('polling cadence', () {
    test('uses active interval while sending or inference is active', () {
      expect(
        chatPollInterval(isSending: true, inferenceActive: false),
        const Duration(seconds: 3),
      );
      expect(
        chatPollInterval(isSending: false, inferenceActive: true),
        const Duration(seconds: 3),
      );
    });

    test('uses idle interval when no send or inference is active', () {
      expect(
        chatPollInterval(isSending: false, inferenceActive: false),
        const Duration(seconds: 10),
      );
    });
  });

  group('chat timestamp labels', () {
    test('formats backend UTC timestamps in local time', () {
      final utcTimestamp = DateTime.utc(2026, 5, 15, 8, 0);
      final localTimestamp = utcTimestamp.toLocal();

      expect(
        chatMessageTimestampLabel(utcTimestamp),
        chatMessageTimestampLabel(localTimestamp),
      );
      if (localTimestamp.timeZoneOffset != Duration.zero) {
        expect(chatMessageTimestampLabel(utcTimestamp), isNot('8:00 AM'));
      }
    });
  });

  group('media relay confirmation', () {
    test('detects relay media confirmation maia_note', () {
      final message = _message(
        'confirm-1',
        type: 'maia_note',
        body: 'Want me to send the image to Mira?',
        extra: {'kind': 'relay_media_confirm'},
      );

      expect(isRelayMediaConfirmMessage(message), isTrue);
      expect(shouldRenderChatMessage(message), isTrue);
    });
  });

  group('message attachments', () {
    test('extracts and renders maia_note attachments', () {
      final message = _message(
        'note-1',
        type: 'maia_note',
        body: '',
        extra: {
          'attachments': [
            {
              'asset_id': 'asset-1',
              'ref': 'image-1',
              'kind': 'image',
              'status': 'ready',
              'mime_type': 'image/png',
            },
          ],
        },
      );

      final attachments = messageAttachmentsOf(message);

      expect(attachments, hasLength(1));
      expect(attachments.single.assetId, 'asset-1');
      expect(attachments.single.ref, 'image-1');
      expect(attachments.single.kind, 'image');
      expect(attachments.single.status, 'ready');
      expect(attachments.single.mimeType, 'image/png');
      expect(shouldRenderChatMessage(message), isTrue);
    });

    test('extracts and renders relay_sent attachments', () {
      final message = _message(
        'relay-sent-1',
        type: 'maia_note',
        body: 'Sent to Mira.',
        extra: {
          'kind': 'relay_sent',
          'target_name': 'Mira Patel',
          'sent_body': 'Sharing the diagram with you.',
          'attachments': [
            {'asset_id': 'asset-2', 'ref': 'video-1', 'kind': 'video'},
          ],
        },
      );

      final attachments = messageAttachmentsOf(message);

      expect(attachments, hasLength(1));
      expect(attachments.single.assetId, 'asset-2');
      expect(attachments.single.ref, 'video-1');
      expect(attachments.single.kind, 'video');
      expect(attachments.single.status, 'pending');
      expect(shouldRenderChatMessage(message), isTrue);
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

String _messageJson(String id, {required String type, required String body}) {
  return '''
{
  "id": "$id",
  "thread_id": "thread-1",
  "type": "$type",
  "body": "$body",
  "tone": null,
  "from_user_id": null,
  "to_user_id": null,
  "to_audience": null,
  "recipient": null,
  "replies_to_message_id": null,
  "reply_to_preview": null,
  "original_text": null,
  "extra": null,
  "prompt_version_id": null,
  "created_at": "2026-05-22T12:00:01Z",
  "resolved_at": null
}
''';
}

Message _message(
  String id, {
  required String body,
  String type = 'user_reply',
  Map<String, dynamic>? extra,
}) {
  return Message(
    id: id,
    threadId: 'thread-1',
    type: type,
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
