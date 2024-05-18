// @author viniciusddrft

import 'dart:async';
import 'dart:io';
import 'package:sparky/src/sparky_server_base.dart';
import 'package:sparky/src/types/sparky_types.dart';
import 'errors/sparky_error.dart';
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
    super.pipelineBefore,
    super.pipelineAfter,
  }) {
    _start();
    _routeMap = {for (final route in routes) route.name: route};
  }

  late final HttpServer _server;
  late final Map<String, Route> _routeMap;

  ///Private function checks for routes with duplicate names.
  bool _checkRepeatedRoutes(Iterable<String> routes) {
    final checkedElements = <String>{};

    return routes.any((name) => !checkedElements.add(name));
  }

  ///Private function that initializes Sparky.
  void _start() async {
    if (_checkRepeatedRoutes(routes.map((e) => e.name))) {
      throw RoutesRepeated();
    } else if (routes.isEmpty) {
      throw ErrorRouteEmpty();
    }

    _server = await HttpServer.bind(ip, port);

    _openServerLog();

    _listenHttp(
      (HttpRequest request) async {
        final response = request.response;

        Response? pipelineBeforeResponse;

        ///Logic to run (N) middlewares before the main route.
        if (pipelineBefore?.mids.isNotEmpty != null) {
          for (final mid in pipelineBefore!.mids) {
            final response = await mid(request);
            if (response != null) {
              pipelineBeforeResponse = response;
            }
          }
        }
        if (WebSocketTransformer.isUpgradeRequest(request) &&
            _routeMap[request.uri.path] != null) {
          final websocket = await WebSocketTransformer.upgrade(request);

          _routeMap[request.uri.path]!.middlewareWebSocket!(websocket);
        } else {
          final Response routeResponse;

          if (pipelineBeforeResponse == null) {
            routeResponse = await _internalHandler(request);
          } else {
            routeResponse = pipelineBeforeResponse;
          }

          response
            ..headers.contentType =
                routeResponse.contentType ?? ContentType.json
            ..statusCode = routeResponse.status
            ..write(routeResponse.body);
          response.close();

          ///Logic to run (N) middlewares after the main route.
          if (pipelineAfter?.mids.isNotEmpty != null) {
            for (final mid in pipelineAfter!.mids) {
              await mid(request);
            }
          }

          _requestServerLog(request, routeResponse);
        }
      },
      onError: (e) {
        _errorServerLog(e);
        _file?.flush();
        _file?.close();
      },
      onDone: () {
        _file?.flush();
        _file?.close();
      },
    );
  }

  /// Private function that handles executing the code for each route.
  Future<Response> _internalHandler(HttpRequest request) async {
    final Route? route = _routeMap[request.uri.path];

    if (route != null) {
      final acceptedMethods = route.acceptedMethods?.map((e) => e.text);
      if (acceptedMethods != null &&
          acceptedMethods.contains(request.method) &&
          route.middleware != null) {
        return route.middleware!(request);
      } else {
        return Route(
          '/405',
          middleware: (request) async {
            return Response.notFound(
                body: "{'errorCode':'405','message':'Method Not Allowed'}");
          },
        ).middleware!(request);
      }
    } else {
      return Route('/404', middleware: (request) async {
        return await routeNotFound?.middleware!(request) ??
            Response.notFound(
                body: "{'errorCode':'404','message':'Not Found'}");
      }).middleware!(request);
    }
  }

  /// Private function that listens for HTTP requests.
  StreamSubscription<HttpRequest> _listenHttp(
      void Function(HttpRequest)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    return _server.listen(onData,
        onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }
}
