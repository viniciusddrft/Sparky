// @author viniciusddrft

import '../types/sparky_types.dart';
import 'route_base.dart';

/// HTTP route class, already equipped with constructors to handle [Get], [Post], [Put], [Delete]
/// but it's possible to customize and make your route work with more than one method.
final class RouteHttp extends Route {
  const RouteHttp(super.name,
      {required super.middleware,
      super.acceptedMethods = const [
        AcceptedMethods.get,
        AcceptedMethods.post,
        AcceptedMethods.put,
        AcceptedMethods.delete,
      ]});

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
}
