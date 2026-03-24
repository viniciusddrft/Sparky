// Author: viniciusddrft

import 'dart:io';
import 'package:sparky/src/response/response.dart';
import 'package:sparky/src/types/sparky_types.dart';

/// Configuration for Cross-Origin Resource Sharing (CORS).
///
/// Use [CorsConfig.permissive] for development (allows everything),
/// or create a custom config for production.
///
/// Per the CORS specification, `Access-Control-Allow-Origin` accepts only
/// `*` or a single specific origin. When [allowOrigins] contains multiple
/// entries, the middleware checks the request's `Origin` header and reflects
/// it back if it is in the allowed list.
final class CorsConfig {
  final List<String> allowOrigins, allowMethods, allowHeaders;
  final bool allowCredentials;
  final int maxAge;

  const CorsConfig({
    this.allowOrigins = const ['*'],
    this.allowMethods = const [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'OPTIONS'
    ],
    this.allowHeaders = const ['Content-Type', 'Authorization'],
    this.allowCredentials = false,
    this.maxAge = 86400,
  });

  /// A permissive CORS configuration that allows all origins and methods.
  const CorsConfig.permissive()
      : allowOrigins = const ['*'],
        allowMethods = const [
          'GET',
          'POST',
          'PUT',
          'DELETE',
          'PATCH',
          'HEAD',
          'OPTIONS'
        ],
        allowHeaders = const ['*'],
        allowCredentials = false,
        maxAge = 86400;

  /// Creates a CORS middleware that can be added to [pipelineBefore].
  ///
  /// Handles preflight `OPTIONS` requests automatically, returning
  /// a 204 with the appropriate headers. For other requests, returns
  /// `null` so the pipeline continues, but the CORS headers are set
  /// directly on the response.
  MiddlewareNulable createMiddleware() {
    return (HttpRequest request) async {
      final requestOrigin = request.headers.value('origin');
      if (request.method == 'OPTIONS') {
        return Response.noContent(
          body: '',
          headers: _corsHeaders(requestOrigin),
        );
      }
      _applyCorsHeaders(request.response, requestOrigin);
      return null;
    };
  }

  /// Resolves which origin to return in the `Access-Control-Allow-Origin`
  /// header based on the request's `Origin` and the configured [allowOrigins].
  ///
  /// Per the CORS specification, `Access-Control-Allow-Origin: *` is not
  /// allowed when credentials are enabled. In that case the request origin
  /// is reflected back instead (if present).
  String? _resolveAllowOrigin(String? requestOrigin) {
    if (allowOrigins.contains('*')) {
      if (allowCredentials && requestOrigin != null) return requestOrigin;
      return '*';
    }
    if (requestOrigin != null && allowOrigins.contains(requestOrigin)) {
      return requestOrigin;
    }
    return null;
  }

  Map<String, String> _corsHeaders(String? requestOrigin) {
    final origin = _resolveAllowOrigin(requestOrigin);
    return {
      if (origin != null) 'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': allowMethods.join(', '),
      'Access-Control-Allow-Headers': allowHeaders.join(', '),
      'Access-Control-Max-Age': maxAge.toString(),
      if (allowCredentials) 'Access-Control-Allow-Credentials': 'true',
      if (origin != null && origin != '*') 'Vary': 'Origin',
    };
  }

  void _applyCorsHeaders(HttpResponse response, String? requestOrigin) {
    final origin = _resolveAllowOrigin(requestOrigin);
    if (origin != null) {
      response.headers.set('Access-Control-Allow-Origin', origin);
    }
    response.headers
        .set('Access-Control-Allow-Methods', allowMethods.join(', '));
    response.headers
        .set('Access-Control-Allow-Headers', allowHeaders.join(', '));
    response.headers.set('Access-Control-Max-Age', maxAge.toString());
    if (allowCredentials) {
      response.headers.set('Access-Control-Allow-Credentials', 'true');
    }
    if (origin != null && origin != '*') {
      response.headers.set('Vary', 'Origin');
    }
  }
}
