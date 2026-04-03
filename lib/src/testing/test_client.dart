// Author: viniciusddrft
//
// In-memory test client for Sparky servers.
//
// Boots a real server on an OS-assigned port (port 0) and provides
// a clean API for making requests without manual HttpClient management.
//
// Example:
// ```dart
// import 'package:sparky/sparky.dart';
// import 'package:sparky/testing.dart';
// import 'package:test/test.dart';
//
// void main() {
//   late SparkyTestClient client;
//
//   setUp(() async {
//     client = await SparkyTestClient.boot(
//       routes: [
//         RouteHttp.get('/hello',
//             middleware: (r) async => const Response.ok(body: 'hi')),
//       ],
//     );
//   });
//
//   tearDown(() => client.close());
//
//   test('GET /hello', () async {
//     final res = await client.get('/hello');
//     expect(res.statusCode, 200);
//     expect(res.body, '"hi"');
//   });
// }
// ```

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sparky/sparky.dart';

/// A simplified HTTP response returned by [SparkyTestClient].
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

/// In-memory test client for Sparky servers.
///
/// Boots a real Sparky server on an OS-assigned port (so no port conflicts)
/// and provides a clean API for making requests in tests.
///
/// ```dart
/// late SparkyTestClient client;
///
/// setUp(() async {
///   client = await SparkyTestClient.boot(
///     routes: [
///       RouteHttp.get('/hello',
///           middleware: (r) async => const Response.ok(body: 'hi')),
///     ],
///   );
/// });
///
/// tearDown(() => client.close());
///
/// test('GET /hello returns 200', () async {
///   final res = await client.get('/hello');
///   expect(res.statusCode, 200);
/// });
/// ```
final class SparkyTestClient {
  final Sparky _server;
  final HttpClient _client;

  SparkyTestClient._(this._server) : _client = HttpClient();

  /// The port the test server is listening on.
  int get port => _server.actualPort;

  /// The base URL of the test server (e.g. `http://localhost:12345`).
  String get baseUrl => 'http://localhost:$port';

  /// Boots a Sparky server on a random port and returns a test client.
  ///
  /// All server configuration options are supported. The server is
  /// always created with `port: 0` (OS-assigned) and `logConfig: LogConfig.none`
  /// by default to keep test output clean.
  static Future<SparkyTestClient> boot({
    required List<Route> routes,
    Route? routeNotFound,
    Pipeline? pipelineBefore,
    Pipeline? pipelineAfter,
    int? maxBodySize,
    Duration? requestTimeout,
    bool enableGzip = false,
    int gzipMinLength = 0,
    Duration? cacheTtl,
    int? cacheMaxEntries,
  }) async {
    final server = Sparky.server(
      routes: routes,
      port: 0,
      logConfig: LogConfig.none,
      routeNotFound: routeNotFound,
      pipelineBefore: pipelineBefore,
      pipelineAfter: pipelineAfter,
      maxBodySize: maxBodySize,
      requestTimeout: requestTimeout,
      enableGzip: enableGzip,
      gzipMinLength: gzipMinLength,
      cacheTtl: cacheTtl,
      cacheMaxEntries: cacheMaxEntries,
    );
    await server.ready;
    return SparkyTestClient._(server);
  }

  /// Wraps an already-running [Sparky] instance in a test client.
  ///
  /// The server must have been started and [Sparky.ready] must have
  /// completed before calling this.
  factory SparkyTestClient.from(Sparky server) {
    return SparkyTestClient._(server);
  }

  /// Sends a GET request to the given [path].
  Future<TestResponse> get(
    String path, {
    Map<String, String>? headers,
  }) =>
      _request('GET', path, headers: headers);

  /// Sends a POST request to the given [path].
  Future<TestResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    ContentType? contentType,
  }) =>
      _request('POST', path,
          body: body, headers: headers, contentType: contentType);

  /// Sends a PUT request to the given [path].
  Future<TestResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
    ContentType? contentType,
  }) =>
      _request('PUT', path,
          body: body, headers: headers, contentType: contentType);

  /// Sends a PATCH request to the given [path].
  Future<TestResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
    ContentType? contentType,
  }) =>
      _request('PATCH', path,
          body: body, headers: headers, contentType: contentType);

  /// Sends a DELETE request to the given [path].
  Future<TestResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
    ContentType? contentType,
  }) =>
      _request('DELETE', path,
          body: body, headers: headers, contentType: contentType);

  /// Sends a HEAD request to the given [path].
  Future<TestResponse> head(
    String path, {
    Map<String, String>? headers,
  }) =>
      _request('HEAD', path, headers: headers);

  /// Sends a request with the given [method] and [path].
  ///
  /// When [body] is a [Map] or [List], it is JSON-encoded and the
  /// content type is set to `application/json` (unless overridden).
  /// When [body] is a [String], it is sent as-is.
  Future<TestResponse> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    ContentType? contentType,
  }) async {
    final request = await _client.open(method, 'localhost', port, path);

    // Apply headers
    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
    }

    // Write body
    if (body != null) {
      final effectiveContentType = contentType ??
          (body is Map || body is List ? ContentType.json : null);
      if (effectiveContentType != null) {
        request.headers.contentType = effectiveContentType;
      }
      if (body is String) {
        request.write(body);
      } else if (body is List<int>) {
        request.add(body);
      } else {
        request.write(json.encode(body));
      }
    }

    final response = await request.close();
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final responseBytes = builder.takeBytes();
    final responseBody = utf8.decode(responseBytes, allowMalformed: true);

    return TestResponse(
      statusCode: response.statusCode,
      body: responseBody,
      bodyBytes: responseBytes,
      headers: response.headers,
      cookies: response.cookies,
    );
  }

  /// Shuts down the test server and closes the HTTP client.
  Future<void> close() async {
    _client.close();
    await _server.close();
  }
}
