// @author viniciusddrft

import '../types/sparky_types.dart';

/// Base class of a route in Spark; HTTP routes and WebSocket routes extend directly from it.
base class Route {
  final String name;
  final Middleware? middleware;
  final MiddlewareWebSocket? middlewareWebSocket;
  final List<AcceptedMethods>? acceptedMethods;

  const Route(this.name,
      {this.middleware,
      this.middlewareWebSocket,
      this.acceptedMethods = const [
        AcceptedMethods.get,
        AcceptedMethods.post,
        AcceptedMethods.put,
        AcceptedMethods.delete
      ]});
}
