/// Low-level exceptions thrown by data sources (network / cache).
///
/// They get caught at the repository layer and either re-thrown as-is to
/// the presentation layer or converted into a [Failure].
sealed class AppException implements Exception {
  const AppException({this.message, this.code, this.statusCode});

  final String? message;

  /// Optional backend-defined error code (e.g. `OTP_EXPIRED`).
  final String? code;

  /// HTTP status code if the exception originated from an HTTP call.
  final int? statusCode;

  @override
  String toString() =>
      '$runtimeType(message: $message, code: $code, status: $statusCode)';
}

/// No internet / DNS / socket failure before reaching the server.
class NetworkException extends AppException {
  const NetworkException({super.message});
}

/// Connect/send/receive timed out.
class TimeoutFailureException extends AppException {
  const TimeoutFailureException({super.message});
}

/// 5xx or unknown 4xx response from the server.
class ServerException extends AppException {
  const ServerException({
    super.message,
    super.code,
    super.statusCode,
  });
}

/// 401 / 403 — the user is not authenticated or not authorised.
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message,
    super.code,
    super.statusCode = 401,
  });
}

/// 422 / 400 with field-level validation errors from the backend.
class ValidationException extends AppException {
  const ValidationException({
    super.message,
    super.code,
    super.statusCode = 422,
    this.fieldErrors,
  });

  final Map<String, List<String>>? fieldErrors;
}

/// 404.
class NotFoundException extends AppException {
  const NotFoundException({
    super.message,
    super.code,
    super.statusCode = 404,
  });
}

/// Request was cancelled (e.g. user navigated away).
class CancelledException extends AppException {
  const CancelledException({super.message});
}

/// Anything wrong with persistent storage (read/write/encode).
class CacheException extends AppException {
  const CacheException({super.message});
}

/// 429 — the user must wait before retrying (e.g. OTP resend cooldown).
class RateLimitException extends AppException {
  const RateLimitException({
    super.message,
    super.code,
    super.statusCode = 429,
    this.retryAfter,
  });

  /// Optional cooldown hint (in seconds) the backend returned.
  final int? retryAfter;
}

/// Catch-all for unexpected errors.
class UnknownException extends AppException {
  const UnknownException({super.message, super.code});
}
