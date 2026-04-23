// Author: viniciusddrft
//
// Typed HTTP exceptions that auto-map to status codes.
//
// Throw these from handlers and the server will automatically
// produce a JSON error response with the correct status code.
//
// Example:
// ```dart
// RouteHttp.get('/users/:id', middleware: (request) async {
//   final user = await findUser(request.pathParams['id']);
//   if (user == null) throw NotFound('User not found');
//   return Response.ok(body: user);
// });
// ```

import 'dart:io';

import '../handler/error_body.dart';

/// Base class for HTTP exceptions that auto-map to status codes.
///
/// When thrown inside a route handler, the server catches it and
/// returns a JSON response with the appropriate status code and body:
/// ```json
/// {"errorCode": "404", "message": "User not found"}
/// ```
///
/// Subclass this to create custom HTTP exceptions with different
/// status codes:
/// ```dart
/// class PaymentRequired extends HttpException {
///   const PaymentRequired([String message = 'Payment Required'])
///       : super(HttpStatus.paymentRequired, message);
/// }
/// ```
class HttpException implements Exception {
  /// The HTTP status code for this exception.
  final int statusCode;

  /// A human-readable error message.
  final String message;

  /// Optional extra data included in the response body.
  final Map<String, Object>? details;

  const HttpException(this.statusCode, this.message, {this.details});

  /// Returns the JSON body for this exception.
  Map<String, Object> toJson() =>
      ErrorBody.toMap(statusCode, message, details: details);

  @override
  String toString() => 'HttpException($statusCode, $message)';
}

// ──────────────────────────────────────────────────────────────────
// 4xx Client Errors
// ──────────────────────────────────────────────────────────────────

/// 400 Bad Request
class BadRequest extends HttpException {
  const BadRequest({String message = 'Bad Request', Map<String, Object>? details})
      : super(HttpStatus.badRequest, message, details: details);
}

/// 401 Unauthorized
class Unauthorized extends HttpException {
  const Unauthorized({String message = 'Unauthorized', Map<String, Object>? details})
      : super(HttpStatus.unauthorized, message, details: details);
}

/// 403 Forbidden
class Forbidden extends HttpException {
  const Forbidden({String message = 'Forbidden', Map<String, Object>? details})
      : super(HttpStatus.forbidden, message, details: details);
}

/// 404 Not Found
class NotFound extends HttpException {
  const NotFound({String message = 'Not Found', Map<String, Object>? details})
      : super(HttpStatus.notFound, message, details: details);
}

/// 405 Method Not Allowed
class MethodNotAllowed extends HttpException {
  const MethodNotAllowed({String message = 'Method Not Allowed', Map<String, Object>? details})
      : super(HttpStatus.methodNotAllowed, message, details: details);
}

/// 409 Conflict
class Conflict extends HttpException {
  const Conflict({String message = 'Conflict', Map<String, Object>? details})
      : super(HttpStatus.conflict, message, details: details);
}

/// 422 Unprocessable Entity
class UnprocessableEntity extends HttpException {
  const UnprocessableEntity({String message = 'Unprocessable Entity', Map<String, Object>? details})
      : super(HttpStatus.unprocessableEntity, message, details: details);
}

/// 429 Too Many Requests
class TooManyRequests extends HttpException {
  const TooManyRequests({String message = 'Too Many Requests', Map<String, Object>? details})
      : super(HttpStatus.tooManyRequests, message, details: details);
}

// ──────────────────────────────────────────────────────────────────
// 5xx Server Errors
// ──────────────────────────────────────────────────────────────────

/// 500 Internal Server Error
class InternalServerError extends HttpException {
  const InternalServerError({String message = 'Internal Server Error', Map<String, Object>? details})
      : super(HttpStatus.internalServerError, message, details: details);
}

/// 502 Bad Gateway
class BadGateway extends HttpException {
  const BadGateway({String message = 'Bad Gateway', Map<String, Object>? details})
      : super(HttpStatus.badGateway, message, details: details);
}

/// 503 Service Unavailable
class ServiceUnavailable extends HttpException {
  const ServiceUnavailable({String message = 'Service Unavailable', Map<String, Object>? details})
      : super(HttpStatus.serviceUnavailable, message, details: details);
}
