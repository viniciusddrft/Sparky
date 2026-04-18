// Author: viniciusddrft

import '../openapi/openapi_types.dart';
import '../types/sparky_types.dart';

/// Base class of a route in Sparky; HTTP routes and WebSocket routes extend directly from it.
///
/// Supports dynamic path parameters using `:param` syntax (e.g. `/users/:id`).
base class Route {
  final String name;
  final Middleware? middleware;
  final MiddlewareWebSocket? middlewareWebSocket;
  final List<AcceptedMethods>? acceptedMethods;

  /// Middleware guards that run before the route handler.
  ///
  /// Each guard is a [MiddlewareNullable]. If any guard returns a [Response],
  /// the pipeline short-circuits and that response is sent to the client.
  /// If all guards return `null`, the route handler executes normally.
  final List<MiddlewareNullable> guards;

  int _versionCache = 0;

  int get versionCache => _versionCache;

  /// Whether this route contains dynamic path segments (`:param`).
  late final bool isDynamic = name.contains(':');

  /// Pre-compiled regex for matching dynamic routes.
  late final RegExp? _pattern = isDynamic ? _buildPattern() : null;

  /// The parameter names extracted from the route pattern.
  late final List<String> _paramNames =
      isDynamic ? _extractParamNames() : const [];

  /// Names of path parameters (without the `:` prefix), in path order.
  ///
  /// Empty when [isDynamic] is false.
  List<String> get pathParameterNames =>
      isDynamic ? List<String>.unmodifiable(_paramNames) : const [];

  /// Whether this route handles HTTP requests via [middleware].
  ///
  /// WebSocket-only routes use [middlewareWebSocket] and leave [middleware] null.
  bool get isHttpRoute => middleware != null;

  /// Optional OpenAPI documentation for this operation (OpenAPI 3.x).
  final OpenApiOperation? openApi;

  Route(this.name,
      {this.middleware,
      this.middlewareWebSocket,
      this.guards = const [],
      this.openApi,
      this.acceptedMethods = const [
        AcceptedMethods.get,
        AcceptedMethods.post,
        AcceptedMethods.put,
        AcceptedMethods.delete,
        AcceptedMethods.patch,
        AcceptedMethods.head,
        AcceptedMethods.options,
        AcceptedMethods.trace
      ]});

  void onUpdate() {
    _versionCache += 1;
  }

  /// Tries to match the given [path] against this route's pattern.
  /// Returns the extracted parameters if matched, or `null` if no match.
  Map<String, String>? matchPath(String path) {
    if (!isDynamic) {
      return path == name ? const {} : null;
    }
    final match = _pattern!.firstMatch(path);
    if (match == null) return null;

    final params = <String, String>{};
    for (var i = 0; i < _paramNames.length; i++) {
      params[_paramNames[i]] = match.group(i + 1)!;
    }
    return params;
  }

  RegExp _buildPattern() {
    final segments = name.split('/');
    final regexParts = segments.map((seg) {
      if (seg.startsWith(':')) return '([^/]+)';
      return RegExp.escape(seg);
    });
    return RegExp('^${regexParts.join('/')}\$');
  }

  List<String> _extractParamNames() {
    return name
        .split('/')
        .where((seg) => seg.startsWith(':'))
        .map((seg) => seg.substring(1))
        .toList();
  }
}
