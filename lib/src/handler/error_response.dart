// @author viniciusddrft

import 'dart:async';
import 'dart:io';

import '../errors/http_exception.dart';
import '../request/sparky_request.dart' show BodyTooLargeException, SparkyRequest;
import 'error_body.dart';

/// Canonical description of an error response.
///
/// Built by [errorInfoFor] from a caught error and consumed by the request
/// handler to produce the actual HTTP response. Keeping this as plain data
/// makes the mapping unit-testable without standing up a server.
class ErrorInfo {
  /// HTTP status code to send.
  final int status;

  /// JSON-encoded response body.
  final String body;

  /// Pre-formatted message to feed into the server's error log.
  final String logMessage;

  const ErrorInfo({
    required this.status,
    required this.body,
    required this.logMessage,
  });
}

/// Maps a caught error to the canonical [ErrorInfo] used by the handler.
///
/// [path] is included in the log message so operators can correlate the
/// log line with the offending request. [requestId], when provided, is
/// embedded into the JSON error body so clients can quote it back for
/// support (only Sparky's JSON log mode passes it today).
ErrorInfo errorInfoFor(Object error, String path, {String? requestId}) {
  if (error is BodyTooLargeException) {
    const status = HttpStatus.requestEntityTooLarge;
    return ErrorInfo(
      status: status,
      body: ErrorBody.toJson(status, 'Request Entity Too Large',
          requestId: requestId),
      logMessage: 'Request entity too large: $path',
    );
  }
  if (error is TimeoutException) {
    const status = HttpStatus.requestTimeout;
    return ErrorInfo(
      status: status,
      body: ErrorBody.toJson(status, 'Request Timeout', requestId: requestId),
      logMessage: 'Request timeout: $path',
    );
  }
  if (error is HttpException) {
    return ErrorInfo(
      status: error.statusCode,
      body: ErrorBody.toJson(error.statusCode, error.message,
          details: error.details, requestId: requestId),
      logMessage: 'HTTP ${error.statusCode}: ${error.message} ($path)',
    );
  }
  const status = HttpStatus.internalServerError;
  return ErrorInfo(
    status: status,
    body: ErrorBody.toJson(status, 'Internal Server Error',
        requestId: requestId),
    logMessage: error.toString(),
  );
}

/// Best-effort write of [info] to [request]'s response.
///
/// Swallows secondary errors (e.g. response already started) so that a
/// failure here cannot mask the original error in the caller's catch block.
Future<void> writeErrorResponse(SparkyRequest request, ErrorInfo info) async {
  try {
    final response = request.raw.response;
    response
      ..statusCode = info.status
      ..headers.contentType = ContentType.json
      ..write(info.body);
    await response.close();
  } catch (_) {
    // Response may already be in a non-recoverable state. Caller still gets
    // metrics + log, which is the best we can do.
  }
}
