// @author viniciusddrft

import 'dart:async';
import 'dart:io';
import 'package:sparky/src/sparky_server_base.dart';
import 'package:sparky/src/types/sparky_types.dart';
import 'errors/sparky_error.dart';
import 'extensions/http_request.dart';
import 'response/response.dart';
import 'route/route_base.dart';

part 'package:sparky/src/logs/logs.dart';

/// Main logic file of Sparky's operation.

base class Sparky extends SparkyBase with Logs {
  Sparky.server({
    required super.routes,
    super.port = 8080,
    super.ip = '0.0.0.0',
    super.routeNotFound,
    super.logConfig = LogConfig.showAndWriteLogs,
    super.logType = LogType.all,
    super.logFilePath = 'logs.txt',
    super.pipelineBefore,
    super.pipelineAfter,
  }) {
    _init();
  }

  late final HttpServer _server;
  late final Map<String, Route> _staticRouteMap;
  late final List<Route> _dynamicRoutes;
  StreamSubscription<HttpRequest>? _subscription;

  void _init() {
    if (routes.isEmpty) {
      throw ErrorRouteEmpty();
    }
    if (_checkRepeatedRoutes(routes.map((e) => e.name))) {
      throw RoutesRepeated();
    }
    _staticRouteMap = {
      for (final route in routes)
        if (!route.isDynamic) route.name: route
    };
    _dynamicRoutes = routes.where((r) => r.isDynamic).toList();
    _startFuture = _start();
  }

  late final Future<void> _startFuture;

  /// Returns the future that completes when the server is bound and listening.
  Future<void> get ready => _startFuture;

  bool _checkRepeatedRoutes(Iterable<String> routes) {
    final checkedElements = <String>{};
    return routes.any((name) => !checkedElements.add(name));
  }

  /// Resolves a route for the given [path], setting path params on [request].
  /// Returns `null` if no route matches.
  Route? _resolveRoute(String path, HttpRequest request) {
    final staticRoute = _staticRouteMap[path];
    if (staticRoute != null) return staticRoute;

    for (final route in _dynamicRoutes) {
      final params = route.matchPath(path);
      if (params != null) {
        request.pathParams = params;
        return route;
      }
    }
    return null;
  }

  Future<void> _start() async {
    _server = await HttpServer.bind(ip, port);

    _openServerLog();

    _subscription = _server.listen(
      (HttpRequest request) async {
        try {
          final response = request.response;
          final path = request.uri.path;

          final Response? pipelineBeforeResponse =
              await runPipeline(pipelineBefore, request);

          final route = _resolveRoute(path, request);

          if (WebSocketTransformer.isUpgradeRequest(request) && route != null) {
            final websocket = await WebSocketTransformer.upgrade(request);
            route.middlewareWebSocket!(websocket);
            await runPipeline(pipelineAfter, request);
          } else {
            final Response routeResponse;

            if (pipelineBeforeResponse == null) {
              if (route != null &&
                  cacheManager.verifyVersionCache(route, request.method)) {
                routeResponse = cacheManager.getCache(route, request.method);
              } else {
                routeResponse = await _internalHandler(request, route);
                if (route != null) {
                  cacheManager.saveCache(route, request.method, routeResponse);
                }
              }
            } else {
              routeResponse = pipelineBeforeResponse;
            }

            response
              ..headers.contentType =
                  routeResponse.contentType ?? ContentType.json
              ..statusCode = routeResponse.status;
            if (routeResponse.headers != null) {
              routeResponse.headers!.forEach((key, value) {
                response.headers.set(key, value);
              });
            }
            response.write(routeResponse.body);
            response.close();

            await runPipeline(pipelineAfter, request);
            _requestServerLog(request, routeResponse);
          }
        } catch (e) {
          _errorServerLog(e);
          try {
            final response = request.response;
            response
              ..statusCode = HttpStatus.internalServerError
              ..headers.contentType = ContentType.json
              ..write('{"errorCode":"500","message":"Internal Server Error"}');
            response.close();
          } catch (_) {}
        }
      },
      onError: (e) {
        _errorServerLog(e);
      },
      onDone: () {
        _file?.flush();
        _file?.close();
      },
    );
  }

  Future<Response> _internalHandler(HttpRequest request, Route? route) async {
    if (route != null) {
      final acceptedMethods = route.acceptedMethods?.map((e) => e.text);
      if (acceptedMethods != null &&
          acceptedMethods.contains(request.method) &&
          route.middleware != null) {
        return route.middleware!(request);
      }
      return const Response.methodNotAllowed(
          body: '{"errorCode":"405","message":"Method Not Allowed"}');
    }

    if (routeNotFound?.middleware != null) {
      return routeNotFound!.middleware!(request);
    }
    return const Response.notFound(
        body: '{"errorCode":"404","message":"Not Found"}');
  }

  /// Gracefully shuts down the server.
  Future<void> close() async {
    await _subscription?.cancel();
    await _server.close();
    await _file?.flush();
    await _file?.close();
  }
}
