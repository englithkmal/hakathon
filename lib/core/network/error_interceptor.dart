import 'package:dio/dio.dart';

import '../errors/exceptions.dart';

/// Normalises every [DioException] thrown by Dio into one of our
/// [AppException]s. Data sources can then `throw e` and stay agnostic of Dio.
class ErrorInterceptor extends Interceptor {
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mapped = mapDioException(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mapped,
        stackTrace: err.stackTrace,
        message: err.message,
      ),
    );
  }
}

/// Translates a [DioException] into the matching [AppException].
///
/// Reads optional shape from a typical JSON error envelope:
/// ```
/// { "message": "...", "code": "OTP_EXPIRED", "errors": { "field": [".."] } }
/// ```
AppException mapDioException(DioException err) {
  switch (err.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return TimeoutFailureException(message: err.message);

    case DioExceptionType.connectionError:
      return NetworkException(message: err.message);

    case DioExceptionType.cancel:
      return CancelledException(message: err.message);

    case DioExceptionType.badCertificate:
      return NetworkException(message: err.message);

    case DioExceptionType.badResponse:
      return _fromBadResponse(err);

    case DioExceptionType.unknown:
      // SocketException etc. usually surface as `unknown` with an inner error.
      final inner = err.error?.toString() ?? err.message;
      return UnknownException(message: inner);
  }
}

AppException _fromBadResponse(DioException err) {
  final response = err.response;
  final status = response?.statusCode;
  final data = response?.data;

  String? message;
  String? code;
  Map<String, List<String>>? fieldErrors;

  if (data is Map<String, dynamic>) {
    final rawMsg = data['message'] ?? data['error'] ?? data['detail'];
    if (rawMsg is String) message = rawMsg;
    final rawCode = data['code'] ?? data['error_code'];
    if (rawCode is String) code = rawCode;
    final rawErrors = data['errors'];
    if (rawErrors is Map) {
      fieldErrors = rawErrors.map(
        (k, v) => MapEntry(
          k.toString(),
          (v is List)
              ? v.map((e) => e.toString()).toList()
              : <String>[v.toString()],
        ),
      );
    }
  } else if (data is String && data.isNotEmpty) {
    message = data;
  }

  switch (status) {
    case 400:
    case 422:
      return ValidationException(
        message: message,
        code: code,
        statusCode: status,
        fieldErrors: fieldErrors,
      );
    case 401:
    case 403:
      return UnauthorizedException(
        message: message,
        code: code,
        statusCode: status!,
      );
    case 404:
      return NotFoundException(
        message: message,
        code: code,
        statusCode: 404,
      );
    case 429:
      return RateLimitException(
        message: message,
        code: code,
        retryAfter: _parseRetryAfter(response),
      );
    default:
      return ServerException(
        message: message,
        code: code,
        statusCode: status,
      );
  }
}

int? _parseRetryAfter(Response<dynamic>? response) {
  if (response == null) return null;
  final headerVal = response.headers.value('retry-after');
  if (headerVal != null) {
    final parsed = int.tryParse(headerVal);
    if (parsed != null) return parsed;
  }
  final data = response.data;
  if (data is Map) {
    final raw = data['data'];
    if (raw is Map) {
      final v = raw['cooldown_seconds'] ?? raw['retry_after'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
  }
  return null;
}
