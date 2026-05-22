// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'browser_push_types.dart';

const _dismissKey = 'maia_push_prompt_dismissed_at';
const _nagInterval = Duration(days: 7);

Future<BrowserPushResult> ensureBrowserPushSubscription({
  required bool promptIfDefault,
  required Map<String, String> firebaseConfig,
}) async {
  final bridge = js.context['maiaPush'];
  if (bridge is! js.JsObject) {
    return const BrowserPushResult(status: BrowserPushStatus.unsupported);
  }

  try {
    final completer = Completer<BrowserPushResult>();
    bridge.callMethod('ensureSubscriptionCallback', <Object?>[
      js.JsObject.jsify(firebaseConfig),
      promptIfDefault,
      js.JsFunction.withThis((_, Object? result) {
        final jsResult = result as js.JsObject?;
        final status = jsResult?['status']?.toString();
        final token = jsResult?['token']?.toString();
        if (!completer.isCompleted) {
          completer.complete(
            BrowserPushResult(
              status: parseBrowserPushStatus(status ?? 'error'),
              token: token == null || token.isEmpty ? null : token,
            ),
          );
        }
      }),
    ]);
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => const BrowserPushResult(status: BrowserPushStatus.error),
    );
  } catch (_) {
    return const BrowserPushResult(status: BrowserPushStatus.error);
  }
}

bool isPushDismissedRecently() {
  try {
    final raw = html.window.localStorage[_dismissKey];
    if (raw == null || raw.isEmpty) {
      return false;
    }
    final timestamp = int.tryParse(raw);
    if (timestamp == null) {
      return false;
    }
    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(dismissedAt) < _nagInterval;
  } catch (_) {
    return false;
  }
}

void markPushDismissed() {
  try {
    html.window.localStorage[_dismissKey] = DateTime.now()
        .millisecondsSinceEpoch
        .toString();
  } catch (_) {}
}

String detectPushPlatform() {
  final ua = html.window.navigator.userAgent;
  if (ua.contains(RegExp('iPhone|iPad|iPod'))) {
    return 'ios';
  }
  if (ua.contains('Android')) {
    return 'android';
  }
  if (ua.contains('Mac')) {
    return 'macos';
  }
  if (ua.contains('Windows')) {
    return 'windows';
  }
  if (ua.contains('Linux')) {
    return 'linux';
  }
  return 'web';
}
