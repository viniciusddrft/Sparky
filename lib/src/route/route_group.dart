// Author: viniciusddrft

import '../types/sparky_types.dart';
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

  /// Guards that apply to all routes in this group.
  ///
  /// Group guards run before individual route guards.
  final List<MiddlewareNullable> guards;

  RouteGroup(this.prefix,
      {required List<Route> routes, this.guards = const []})
      : _routes = routes;

  /// Expands this group into individual routes with the prefix prepended.
  ///
  /// Group-level [guards] are prepended to each route's own guards,
  /// so they run first during request handling.
  List<Route> flatten() {
    return _routes.map((route) {
      final fullPath = '$prefix${route.name}';
      final combinedGuards = [...guards, ...route.guards];
      if (route is RouteHttp) {
        return RouteHttp(fullPath,
            middleware: route.middleware!,
            acceptedMethods: route.acceptedMethods,
            guards: combinedGuards,
            openApi: route.openApi);
      }
      return Route(fullPath,
          middleware: route.middleware,
          middlewareWebSocket: route.middlewareWebSocket,
          acceptedMethods: route.acceptedMethods,
          guards: combinedGuards,
          openApi: route.openApi);
    }).toList();
  }
}
