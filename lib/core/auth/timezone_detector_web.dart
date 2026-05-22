// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;

String detectTimezone() {
  final value =
      html.window.localStorage['maia_timezone'] ??
      html.window.localStorage['maia_detected_timezone'];
  if (value == null || value.isEmpty) {
    return 'UTC';
  }
  return value;
}
