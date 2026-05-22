enum BrowserPushStatus {
  subscribed,
  permissionDefault,
  permissionDenied,
  needsInstall,
  unsupported,
  error,
}

BrowserPushStatus parseBrowserPushStatus(String value) {
  return switch (value) {
    'subscribed' => BrowserPushStatus.subscribed,
    'permission-default' => BrowserPushStatus.permissionDefault,
    'permission-denied' => BrowserPushStatus.permissionDenied,
    'needs-install' => BrowserPushStatus.needsInstall,
    'unsupported' => BrowserPushStatus.unsupported,
    _ => BrowserPushStatus.error,
  };
}

class BrowserPushResult {
  const BrowserPushResult({required this.status, this.token});

  final BrowserPushStatus status;
  final String? token;
}
