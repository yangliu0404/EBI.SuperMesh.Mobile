/// API exception types for SuperMesh.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? errorCode;
  final dynamic data;

  const ApiException({
    this.statusCode,
    required this.message,
    this.errorCode,
    this.data,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';

  /// No network connection.
  factory ApiException.noConnection() => const ApiException(
        message: 'No internet connection',
        errorCode: 'NO_CONNECTION',
      );

  /// Request timeout.
  factory ApiException.timeout() => const ApiException(
        message: 'Request timed out',
        errorCode: 'TIMEOUT',
      );

  /// Authentication failed.
  factory ApiException.unauthorized() => const ApiException(
        statusCode: 401,
        message: 'Unauthorized',
        errorCode: 'UNAUTHORIZED',
      );

  /// Server error.
  factory ApiException.server([String? message]) => ApiException(
        statusCode: 500,
        message: message ?? 'Internal server error',
        errorCode: 'SERVER_ERROR',
      );
}
