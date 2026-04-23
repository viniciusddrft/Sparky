// @author viniciusddrft

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A simplified HTTP response returned by `SparkyTestClient`.
final class TestResponse {
  /// The HTTP status code.
  final int statusCode;

  /// The response body as a string.
  final String body;

  /// The raw response body as bytes.
  final Uint8List bodyBytes;

  /// The response headers.
  final HttpHeaders headers;

  /// The response cookies.
  final List<Cookie> cookies;

  const TestResponse({
    required this.statusCode,
    required this.body,
    required this.bodyBytes,
    required this.headers,
    required this.cookies,
  });

  /// Parses the body as JSON.
  dynamic get jsonBody => json.decode(body);

  /// The Content-Type of the response.
  ContentType? get contentType => headers.contentType;
}
