// @author viniciusddrft

import 'dart:convert';

/// Canonical builder for error response bodies.
///
/// Every JSON error body produced by Sparky — 4xx routing errors (404, 405),
/// pre-flight errors (413, 408), uncaught exceptions (500), and bodies emitted
/// by [HttpException] subclasses — flows through this single builder. That
/// keeps the wire shape consistent and prevents drift over time.
///
/// Output shape:
/// ```json
/// {"errorCode": "<status>", "message": "<msg>", ...details, "requestId": "<id>"}
/// ```
class ErrorBody {
  /// Returns the canonical error body as a `Map`. Use this when you need
  /// to embed the body in a larger structure or pass it through a typed API.
  static Map<String, Object> toMap(
    int status,
    String message, {
    String? errorCode,
    Map<String, Object>? details,
    String? requestId,
  }) {
    return <String, Object>{
      'errorCode': errorCode ?? status.toString(),
      'message': message,
      if (details != null) ...details,
      if (requestId != null) 'requestId': requestId,
    };
  }

  /// Returns the canonical error body as a JSON-encoded `String`, ready to
  /// write directly to an HTTP response.
  static String toJson(
    int status,
    String message, {
    String? errorCode,
    Map<String, Object>? details,
    String? requestId,
  }) {
    return json.encode(toMap(
      status,
      message,
      errorCode: errorCode,
      details: details,
      requestId: requestId,
    ));
  }
}
