class ApiException implements Exception {
  const ApiException(this.status, this.message);

  final int? status;
  final String message;

  @override
  String toString() {
    final code = status;
    if (code == null) {
      return 'ApiException: $message';
    }
    return 'ApiException($code): $message';
  }
}
