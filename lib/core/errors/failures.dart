import 'exceptions.dart';

/// User-presentable failure wrapper. The presentation layer should only ever
/// see [Failure]s — never raw [AppException]s — so it can map them straight
/// into UI copy / snackbars / dialogs.
sealed class Failure {
  const Failure({this.message, this.code});

  /// Localised, human-friendly message (or fallback English).
  final String? message;

  /// Optional machine code (e.g. `OTP_EXPIRED`) for finer UI branching.
  final String? code;

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.code});
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({super.message, super.code});
}

class ServerFailure extends Failure {
  const ServerFailure({super.message, super.code, this.statusCode});

  final int? statusCode;
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message, super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message,
    super.code,
    this.fieldErrors,
  });

  final Map<String, List<String>>? fieldErrors;
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message, super.code});
}

class CancelledFailure extends Failure {
  const CancelledFailure({super.message, super.code});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message, super.code});
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({super.message, super.code, this.retryAfter});

  /// Cooldown in seconds the UI should respect before retrying.
  final int? retryAfter;
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message, super.code});
}

/// Bridge so the repository layer can write `e.toFailure()`.
extension AppExceptionToFailure on AppException {
  Failure toFailure() {
    return switch (this) {
      NetworkException(:final message) =>
        NetworkFailure(message: message),
      TimeoutFailureException(:final message) =>
        TimeoutFailure(message: message),
      UnauthorizedException(:final message, :final code) =>
        UnauthorizedFailure(message: message, code: code),
      ValidationException(:final message, :final code, :final fieldErrors) =>
        ValidationFailure(
          message: message,
          code: code,
          fieldErrors: fieldErrors,
        ),
      NotFoundException(:final message, :final code) =>
        NotFoundFailure(message: message, code: code),
      CancelledException(:final message) =>
        CancelledFailure(message: message),
      ServerException(:final message, :final code, :final statusCode) =>
        ServerFailure(
          message: message,
          code: code,
          statusCode: statusCode,
        ),
      CacheException(:final message) => CacheFailure(message: message),
      RateLimitException(:final message, :final code, :final retryAfter) =>
        RateLimitFailure(
          message: message,
          code: code,
          retryAfter: retryAfter,
        ),
      UnknownException(:final message, :final code) =>
        UnknownFailure(message: message, code: code),
    };
  }
}
