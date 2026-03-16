// Author: viniciusddrft

import 'dart:io';
import 'package:sparky/src/response/response.dart';
import 'package:sparky/src/types/sparky_types.dart';

/// Configuration for Cross-Origin Resource Sharing (CORS).
///
/// Use [CorsConfig.permissive] for development (allows everything),
/// or create a custom config for production.
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
  /// via a second middleware in [pipelineAfter] if needed.
  MiddlewareNulable createMiddleware() {
    return (HttpRequest request) async {
      if (request.method == 'OPTIONS') {
        return Response.noContent(
          body: '',
          headers: _corsHeaders(),
        );
      }
      _applyCorsHeaders(request.response);
      return null;
    };
  }

  Map<String, String> _corsHeaders() {
    return {
      'Access-Control-Allow-Origin': allowOrigins.join(', '),
      'Access-Control-Allow-Methods': allowMethods.join(', '),
      'Access-Control-Allow-Headers': allowHeaders.join(', '),
      'Access-Control-Max-Age': maxAge.toString(),
      if (allowCredentials) 'Access-Control-Allow-Credentials': 'true',
    };
  }

  void _applyCorsHeaders(HttpResponse response) {
    response.headers
        .set('Access-Control-Allow-Origin', allowOrigins.join(', '));
    response.headers
        .set('Access-Control-Allow-Methods', allowMethods.join(', '));
    response.headers
        .set('Access-Control-Allow-Headers', allowHeaders.join(', '));
    response.headers.set('Access-Control-Max-Age', maxAge.toString());
    if (allowCredentials) {
      response.headers.set('Access-Control-Allow-Credentials', 'true');
    }
  }
}
