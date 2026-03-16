// Author: viniciusddrft

import 'route_base.dart';
import 'route_http.dart';

/// Groups multiple routes under a common path prefix.
///
/// Example:
/// ```dart
/// final apiRoutes = RouteGroup('/api/v1', routes: [
///   RouteHttp.get('/users', middleware: ...),
///   RouteHttp.get('/products', middleware: ...),
/// ]);
/// // Results in routes: /api/v1/users, /api/v1/products
/// ```
///
/// Use [flatten] to expand the group into a flat list of [Route] objects
/// suitable for passing to `Sparky.server(routes: ...)`.
final class RouteGroup {
  final String prefix;
  final List<Route> _routes;

  RouteGroup(this.prefix, {required List<Route> routes}) : _routes = routes;

  /// Expands this group into individual routes with the prefix prepended.
  List<Route> flatten() {
    return _routes.map((route) {
      final fullPath = '$prefix${route.name}';
      if (route is RouteHttp) {
        return RouteHttp(fullPath, middleware: route.middleware!);
      }
      return Route(fullPath,
          middleware: route.middleware,
          middlewareWebSocket: route.middlewareWebSocket,
          acceptedMethods: route.acceptedMethods);
    }).toList();
  }
}
