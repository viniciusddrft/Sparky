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
    super.securityContext,
    super.requestTimeout,
    super.maxBodySize,
    super.enableGzip = false,
    super.gzipMinLength = 0,
    super.cacheTtl,
    super.cacheMaxEntries,
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

  /// The actual port the server is listening on.
  ///
  /// Useful when binding with `port: 0` (OS-assigned port).
  /// Must be called after [ready] completes.
  int get actualPort => _server.port;

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

  bool _isCacheableMethod(String method) =>
      method == 'GET' || method == 'HEAD';

  Future<void> _start() async {
    _server = securityContext != null
        ? await HttpServer.bindSecure(ip, port, securityContext!)
        : await HttpServer.bind(ip, port);

    _openServerLog();

    _subscription = _server.listen(
      (HttpRequest request) async {
        try {
          var upgradedToWebSocket = false;
          if (maxBodySize != null) {
            request.setMaxBodySize(maxBodySize!);
            final contentLength = request.contentLength;
            if (contentLength > maxBodySize!) {
              final response = request.response;
              response
                ..statusCode = HttpStatus.requestEntityTooLarge
                ..headers.contentType = ContentType.json
                ..write(
                    '{"errorCode":"413","message":"Request Entity Too Large"}');
              await response.close();
              return;
            }
            if (contentLength < 0 &&
                request.method != 'GET' &&
                request.method != 'HEAD' &&
                request.method != 'OPTIONS') {
              await request.preloadBodyWithLimit(maxBodySize!);
            }
          }

          Future<Response> resolveResponse() async {
            final path = request.uri.path;

            final Response? pipelineBeforeResponse =
                await runPipeline(pipelineBefore, request);

            final route = _resolveRoute(path, request);

            if (WebSocketTransformer.isUpgradeRequest(request) &&
                route != null) {
              final websocket = await WebSocketTransformer.upgrade(request);
              route.middlewareWebSocket!(websocket);
              upgradedToWebSocket = true;
              return const Response.ok(body: '');
            } else {
              final Response routeResponse;

              if (pipelineBeforeResponse == null) {
                // Cache only applies to static routes (no :param segments)
                // and idempotent methods (GET, HEAD). Dynamic routes and
                // stream responses are intentionally excluded.
                if (route != null &&
                    !route.isDynamic &&
                    _isCacheableMethod(request.method) &&
                    isCached(route, request.method)) {
                  routeResponse = getCachedResponse(route, request.method);
                } else {
                  routeResponse = await _internalHandler(request, route);
                  if (route != null &&
                      !route.isDynamic &&
                      _isCacheableMethod(request.method) &&
                      !routeResponse.isStream) {
                    cacheResponse(route, request.method, routeResponse);
                  }
                }
              } else {
                routeResponse = pipelineBeforeResponse;
              }

              return routeResponse;
            }
          }

          final Response routeResponse;
          if (requestTimeout != null) {
            final handlerFuture = resolveResponse();
            routeResponse = await handlerFuture.timeout(requestTimeout!,
                onTimeout: () {
              request.markCancelled();
              handlerFuture.ignore();
              throw TimeoutException(
                  'Request timeout', requestTimeout);
            });
          } else {
            routeResponse = await resolveResponse();
          }

          if (upgradedToWebSocket) {
            await runPipeline(pipelineAfter, request);
            return;
          }

          final response = request.response;
          response
            ..headers.contentType = routeResponse.contentType ?? ContentType.json
            ..statusCode = routeResponse.status;
          if (routeResponse.headers != null) {
            routeResponse.headers!.forEach((key, value) {
              response.headers.set(key, value);
            });
          }
          if (routeResponse.cookies != null) {
            response.cookies.addAll(routeResponse.cookies!);
          }

          if (routeResponse.isStream) {
            final stream = routeResponse.bodyStream!;
            final canGzipStream = enableGzip &&
                _isCompressibleContentType(routeResponse.contentType) &&
                request.headers[HttpHeaders.acceptEncodingHeader]
                        ?.any((e) => e.contains('gzip')) ==
                    true;
            if (canGzipStream) {
              response.headers.chunkedTransferEncoding = true;
              response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
              response.headers
                  .set(HttpHeaders.contentEncodingHeader, 'gzip');
              await response.addStream(stream.transform(gzip.encoder));
            } else {
              await response.addStream(stream);
            }
          } else {
            final responseBytes = routeResponse.bodyBytes;
            final canGzip = enableGzip &&
                !routeResponse.isBinary &&
                responseBytes.length >= gzipMinLength &&
                request.headers[HttpHeaders.acceptEncodingHeader]
                        ?.any((e) => e.contains('gzip')) ==
                    true;
            if (canGzip) {
              response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
              response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
              response.add(gzip.encode(responseBytes));
            } else {
              response.add(responseBytes);
            }
          }
          await response.close();

          await runPipeline(pipelineAfter, request);
          _requestServerLog(request, routeResponse);
        } on BodyTooLargeException {
          _errorServerLog('Request entity too large: ${request.uri.path}');
          try {
            final response = request.response;
            response
              ..statusCode = HttpStatus.requestEntityTooLarge
              ..headers.contentType = ContentType.json
              ..write('{"errorCode":"413","message":"Request Entity Too Large"}');
            await response.close();
          } catch (_) {}
        } on TimeoutException {
          _errorServerLog('Request timeout: ${request.uri.path}');
          try {
            final response = request.response;
            response
              ..statusCode = HttpStatus.requestTimeout
              ..headers.contentType = ContentType.json
              ..write('{"errorCode":"408","message":"Request Timeout"}');
            await response.close();
          } catch (_) {}
        } catch (e) {
          _errorServerLog(e);
          try {
            final response = request.response;
            response
              ..statusCode = HttpStatus.internalServerError
              ..headers.contentType = ContentType.json
              ..write('{"errorCode":"500","message":"Internal Server Error"}');
            await response.close();
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
        for (final guard in route.guards) {
          final guardResponse = await guard(request);
          if (guardResponse != null) return guardResponse;
        }
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

bool _isCompressibleContentType(ContentType? ct) {
  if (ct == null) return true;
  final primary = ct.primaryType;
  if (primary == 'text') return true;
  if (primary == 'application') {
    return ct.subType == 'json' ||
        ct.subType == 'javascript' ||
        ct.subType == 'xml' ||
        ct.subType == 'svg+xml';
  }
  return false;
}
