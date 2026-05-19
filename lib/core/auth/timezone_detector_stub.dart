String detectTimezone() {
  final now = DateTime.now();
  final name = now.timeZoneName;
  if (_looksLikeIanaTimezone(name)) {
    return name;
  }

  final normalizedName = name.toUpperCase();
  if (normalizedName == 'UTC' || normalizedName == 'GMT') {
    return 'UTC';
  }

  return _timezoneForOffset(now.timeZoneOffset) ?? 'UTC';
}

bool _looksLikeIanaTimezone(String value) {
  return value.contains('/') && !value.contains(' ');
}

String? _timezoneForOffset(Duration offset) {
  return switch (offset.inMinutes) {
    330 => 'Asia/Kolkata',
    0 => 'UTC',
    -240 => 'America/New_York',
    -300 => 'America/New_York',
    -360 => 'America/Chicago',
    -420 => 'America/Denver',
    -480 => 'America/Los_Angeles',
    60 => 'Europe/Berlin',
    120 => 'Europe/Berlin',
    480 => 'Asia/Singapore',
    540 => 'Asia/Tokyo',
    600 => 'Australia/Sydney',
    660 => 'Australia/Sydney',
    _ => null,
  };
}
