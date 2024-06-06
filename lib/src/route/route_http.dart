// @author viniciusddrft

import '../types/sparky_types.dart';
import 'route_base.dart';

/// HTTP route class, already equipped with constructors to handle [Get], [Post], [Put], [Delete]
/// [Patch], [Head], [Options], [Trace] but it's possible to customize and make your route work with more than one method.
final class RouteHttp extends Route {
  RouteHttp(super.name, {required super.middleware});

  RouteHttp.get(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.get]});

  RouteHttp.put(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.put]});

  RouteHttp.delete(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.delete]});

  RouteHttp.post(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.post]});

  RouteHttp.patch(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.patch]});

  RouteHttp.head(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.head]});

  RouteHttp.options(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.options]});

  RouteHttp.trace(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.trace]});
}
