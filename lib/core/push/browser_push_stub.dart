import 'browser_push_types.dart';

Future<BrowserPushResult> ensureBrowserPushSubscription({
  required bool promptIfDefault,
  required Map<String, String> firebaseConfig,
}) async {
  return const BrowserPushResult(status: BrowserPushStatus.unsupported);
}

bool isPushDismissedRecently() => false;

void markPushDismissed() {}

String detectPushPlatform() => 'unknown';
