// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;

Uri currentBrowserUri() => Uri.parse(html.window.location.href);

void replaceBrowserUrl(String path) {
  html.window.history.replaceState(null, '', path);
}
