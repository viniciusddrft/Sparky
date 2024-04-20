// @author viniciusddrft

import '../types/sparky_types.dart';
import 'route_base.dart';

/// HTTP route class, already equipped with constructors to handle [Get], [Post], [Put], [Delete]
/// [Patch], [Head], [Options], [Trace] but it's possible to customize and make your route work with more than one method.
final class RouteHttp extends Route {
  const RouteHttp(super.name, {required super.middleware});

  const RouteHttp.get(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.get]});

  const RouteHttp.put(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.put]});

  const RouteHttp.delete(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.delete]});

  const RouteHttp.post(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.post]});

  const RouteHttp.patch(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.patch]});

  const RouteHttp.head(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.head]});

  const RouteHttp.options(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.options]});

  const RouteHttp.trace(super.name,
      {required super.middleware,
      super.acceptedMethods = const [AcceptedMethods.trace]});
}
