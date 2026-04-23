// Author: viniciusddrft

import '../types/sparky_types.dart';
import 'route_base.dart';

/// HTTP route class, already equipped with constructors to handle [Get], [Post], [Put], [Delete]
/// [Patch], [Head], [Options], [Trace] but it's possible to customize and make your route work with more than one method.
final class RouteHttp extends Route {
  RouteHttp(super.path,
      {required super.middleware,
      super.acceptedMethods,
      super.guards,
      super.openApi});

  RouteHttp.get(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.get]});

  RouteHttp.put(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.put]});

  RouteHttp.delete(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.delete]});

  RouteHttp.post(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.post]});

  RouteHttp.patch(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.patch]});

  RouteHttp.head(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.head]});

  RouteHttp.options(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.options]});

  RouteHttp.trace(super.path,
      {required super.middleware,
      super.guards,
      super.openApi,
      super.acceptedMethods = const [AcceptedMethods.trace]});
}
