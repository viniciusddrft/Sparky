// @author viniciusddrft

import 'dart:async';
import 'dart:io';
import 'package:sparky/src/types/sparky_types.dart';
import 'errors/sparky_error.dart';
import 'response/response.dart';
import 'route/route_base.dart';

part 'package:sparky/src/pipeline/pipeline.dart';

/// Main logic file of Sparky's operation.

base class Sparky {
  Sparky.server({
    required this.routes,
    this.port = 8080,
    this.ip = '0.0.0.0',
    this.routeNotFound,
    this.logConfig = LogConfig.showAndWriteLogs,
    this.logType = LogType.all,
    this.pipelineBefore,
    this.pipelineAfter,
  }) {
    _start();
    _routeMap = {for (var route in routes) route.name: route};
  }

  late final HttpServer _server;
  late final Map<String, Route> _routeMap;
  final List<Route> routes;
  final int port;
  final String ip;
  final Route? routeNotFound;
  final LogConfig logConfig;
  final LogType logType;
  final Pipeline? pipelineBefore, pipelineAfter;
  IOSink? file;

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

    if (logType == LogType.all || logType == LogType.info) {
      if (logConfig == LogConfig.showLogs ||
          logConfig == LogConfig.showAndWriteLogs) {
        print('-- info --> Listen on $ip:$port');
        if (logConfig == LogConfig.writeLogs ||
            logConfig == LogConfig.showAndWriteLogs) {
          file = File('logs.txt').openWrite(mode: FileMode.append);
          _saveLogs('-- info --> Listen on $ip:$port');
        }
      }
    }

    _listenHttp(
      (HttpRequest request) async {
        final response = request.response;

        Response? pipelineBeforeResponse;

        ///Logic to run (N) middlewares before the main route.
        if (pipelineBefore?._mids.isNotEmpty != null) {
          for (final mid in pipelineBefore!._mids) {
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
          if (pipelineAfter?._mids.isNotEmpty != null) {
            for (final mid in pipelineAfter!._mids) {
              await mid(request);
            }
          }

          if (logType == LogType.all || logType == LogType.info) {
            if (logConfig == LogConfig.showLogs ||
                logConfig == LogConfig.showAndWriteLogs) {
              print(
                  '-- info --> Method ${request.method} ${routeResponse.status} ${request.uri.path} from -> ${request.connectionInfo?.remoteAddress.host}');
            }
            if (logConfig == LogConfig.writeLogs ||
                logConfig == LogConfig.showAndWriteLogs) {
              _saveLogs(
                  '-- info --> Method ${request.method} ${routeResponse.status} ${request.uri.path} from -> ${request.connectionInfo?.remoteAddress.host}:');
            }
          }
        }
      },
      onError: (e) {
        if (logType == LogType.all || logType == LogType.errors) {
          if (logConfig == LogConfig.showLogs ||
              logConfig == LogConfig.showAndWriteLogs) {
            print('-- error --> Message $e');
          }
          if (logConfig == LogConfig.writeLogs ||
              logConfig == LogConfig.showAndWriteLogs) {
            _saveLogs('-- error --> Message $e');
          }
        }
        file?.flush();
        file?.close();
      },
      onDone: () {
        file?.flush();
        file?.close();
      },
    );
  }

  /// Private function that handles executing the code for each route.
  Future<Response> _internalHandler(HttpRequest request) async {
    final Route? route = _routeMap[request.uri.path];

    if (route != null) {
      final acceptedMethods = route.acceptedMethods?.map((e) => e.text);
      if (acceptedMethods != null && acceptedMethods.contains(request.method)) {
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

  /// Private function that saves logs.
  void _saveLogs(String message) =>
      file?.write('${DateTime.now()}: $message\n');
}
