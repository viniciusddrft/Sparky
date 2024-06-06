// @author viniciusddrft

import 'package:sparky/sparky.dart';

/// Base class of a route in Spark; HTTP routes and WebSocket routes extend directly from it.
base class Route {
  final String name;
  final Middleware? middleware;
  final MiddlewareWebSocket? middlewareWebSocket;
  final List<AcceptedMethods>? acceptedMethods;
  int _versionCache = 0;

  int get versionCache => _versionCache;

  Route(this.name,
      {this.middleware,
      this.middlewareWebSocket,
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
}
