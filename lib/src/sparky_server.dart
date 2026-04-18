// @author viniciusddrft

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:sparky/src/sparky_server_base.dart';
import 'package:sparky/src/types/sparky_types.dart';
import 'errors/http_exception.dart';
import 'errors/sparky_error.dart';
import 'extensions/http_request.dart';
import 'response/response.dart';
import 'route/route_base.dart';

part 'package:sparky/src/logs/logs.dart';

/// Factory function for creating a Sparky server instance inside an isolate.
///
/// The [isolateIndex] identifies the isolate (0-based). The function must be
/// a **top-level or static function** — closures cannot cross isolate boundaries.
typedef SparkyFactory = FutureOr<Sparky> Function(int isolateIndex);

/// Main logic file of Sparky's operation.

base class Sparky extends SparkyBase with Logs {
  /// Creates a single Sparky server instance in the current isolate.
  ///
  /// Use this for standard deployments where you don't need multi-core
  /// scaling via isolates. For cluster mode, use [Sparky.cluster].
  Sparky.single({
    required super.routes,
    super.openApi,
    super.metrics,
    super.port,
    super.ip,
    super.shared,
    super.routeNotFound,
    super.logConfig,
    super.logType,
    super.logFilePath,
    super.pipelineBefore,
    super.pipelineAfter,
    super.securityContext,
    super.requestTimeout,
    super.maxBodySize,
    super.enableGzip,
    super.gzipMinLength,
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

  bool _isCacheableMethod(String method) => method == 'GET' || method == 'HEAD';

  Future<void> _start() async {
    _server = securityContext != null
        ? await HttpServer.bindSecure(ip, port, securityContext!,
            shared: shared)
        : await HttpServer.bind(ip, port, shared: shared);

    _openServerLog();

    _subscription = _server.listen(
      (HttpRequest request) async {
        final pm = prometheusMetrics;
        pm?.requestStarted();
        final sw = Stopwatch()..start();
        void recordMetrics(int statusCode) {
          pm?.recordHttpRequest(
            method: request.method,
            path: request.uri.path,
            statusCode: statusCode,
            elapsed: sw.elapsed,
          );
        }

        try {
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
                recordMetrics(HttpStatus.requestEntityTooLarge);
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
                  // Cache only applies to static routes (no :param segments),
                  // idempotent methods (GET, HEAD), and routes without guards
                  // (guards evaluate per-request state, e.g. auth). Dynamic
                  // routes and stream responses are intentionally excluded.
                  final cacheable = route != null &&
                      !route.isDynamic &&
                      route.guards.isEmpty &&
                      _isCacheableMethod(request.method);
                  if (cacheable && isCached(route, request.method)) {
                    routeResponse = getCachedResponse(route, request.method);
                  } else {
                    routeResponse = await _internalHandler(request, route);
                    if (cacheable && !routeResponse.isStream) {
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
              routeResponse =
                  await handlerFuture.timeout(requestTimeout!, onTimeout: () {
                request.markCancelled();
                handlerFuture.ignore();
                throw TimeoutException('Request timeout', requestTimeout);
              });
            } else {
              routeResponse = await resolveResponse();
            }

            if (upgradedToWebSocket) {
              await runPipeline(pipelineAfter, request);
              recordMetrics(HttpStatus.switchingProtocols);
              return;
            }

            final response = request.response;
            response
              ..headers.contentType =
                  routeResponse.contentType ?? ContentType.json
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
                response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
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
            recordMetrics(routeResponse.status);
          } on BodyTooLargeException {
            _errorServerLog('Request entity too large: ${request.uri.path}');
            try {
              final response = request.response;
              response
                ..statusCode = HttpStatus.requestEntityTooLarge
                ..headers.contentType = ContentType.json
                ..write(
                    '{"errorCode":"413","message":"Request Entity Too Large"}');
              await response.close();
            } catch (_) {}
            recordMetrics(HttpStatus.requestEntityTooLarge);
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
            recordMetrics(HttpStatus.requestTimeout);
          } on HttpException catch (e) {
            _errorServerLog(
                'HTTP ${e.statusCode}: ${e.message} (${request.uri.path})');
            try {
              final response = request.response;
              response
                ..statusCode = e.statusCode
                ..headers.contentType = ContentType.json
                ..write(json.encode(e.toJson()));
              await response.close();
            } catch (_) {}
            recordMetrics(e.statusCode);
          } catch (e) {
            _errorServerLog(e);
            try {
              final response = request.response;
              response
                ..statusCode = HttpStatus.internalServerError
                ..headers.contentType = ContentType.json
                ..write(
                    '{"errorCode":"500","message":"Internal Server Error"}');
              await response.close();
            } catch (_) {}
            recordMetrics(HttpStatus.internalServerError);
          }
        } finally {
          pm?.requestFinished();
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

  /// Starts a cluster of Sparky servers sharing the same port across isolates.
  ///
  /// [factory] is a **top-level or static function** that creates a configured
  /// [Sparky] instance. It is called once per isolate. The function receives
  /// the isolate index (0-based) as a parameter. The server **must** be
  /// created with `shared: true` for port sharing to work.
  ///
  /// [isolates] is the total number of server instances (including the main
  /// isolate). Defaults to [Platform.numberOfProcessors].
  ///
  /// Returns a [SparkyCluster] that can be used to shut down all isolates.
  ///
  /// Example:
  /// ```dart
  /// Sparky createServer(int isolateIndex) {
  ///   return Sparky.single(
  ///     port: 8080,
  ///     shared: true,
  ///     routes: [...],
  ///   );
  /// }
  ///
  /// void main() async {
  ///   final cluster = await Sparky.cluster(createServer, isolates: 4);
  ///   print('Listening on port ${cluster.port}');
  /// }
  /// ```
  static Future<SparkyCluster> cluster(
    SparkyFactory factory, {
    int? isolates,
  }) async {
    final isolateCount = isolates ?? Platform.numberOfProcessors;
    assert(isolateCount >= 1, 'isolates must be >= 1');

    final mainServer = await factory(0);
    await mainServer.ready;

    if (mainServer.port != 0 || isolateCount == 1) {
      // All good — proceed
    } else {
      throw StateError('port: 0 is not supported with multiple isolates. '
          'Use an explicit port when using Sparky.cluster() with isolates > 1.');
    }

    final workerIsolates = <Isolate>[];
    final shutdownPorts = <SendPort>[];

    try {
      for (var i = 1; i < isolateCount; i++) {
        final receivePort = ReceivePort();
        final completer = Completer<SendPort>();

        receivePort.listen((message) {
          if (message is SendPort) {
            completer.complete(message);
          } else if (message is List && message.length == 2) {
            // Error from worker isolate: [error, stackTrace]
            receivePort.close();
            if (!completer.isCompleted) {
              completer.completeError(
                StateError('Worker isolate $i failed: ${message[0]}'),
              );
            }
          }
        });

        final isolate = await Isolate.spawn(
          _isolateEntryPoint,
          (factory, i, receivePort.sendPort),
          onError: receivePort.sendPort,
        );

        final shutdownPort = await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            receivePort.close();
            isolate.kill(priority: Isolate.immediate);
            throw TimeoutException(
              'Worker isolate $i failed to start within 10 seconds',
            );
          },
        );

        shutdownPorts.add(shutdownPort);
        workerIsolates.add(isolate);
      }
    } catch (e) {
      // Rollback: kill all already-spawned isolates and close main server
      for (var j = 0; j < workerIsolates.length; j++) {
        shutdownPorts[j].send(null);
        workerIsolates[j].kill(priority: Isolate.immediate);
      }
      await mainServer.close();
      rethrow;
    }

    return SparkyCluster._(
      isolates: workerIsolates,
      shutdownPorts: shutdownPorts,
      mainServer: mainServer,
    );
  }

  /// Gracefully shuts down the server.
  Future<void> close() async {
    await _subscription?.cancel();
    await _server.close();
    await _file?.flush();
    await _file?.close();
  }
}

Future<void> _isolateEntryPoint((SparkyFactory, int, SendPort) config) async {
  final (factory, index, mainSendPort) = config;
  final shutdownPort = ReceivePort();

  final server = await factory(index);
  await server.ready;

  // Send the shutdown port only after successful startup
  mainSendPort.send(shutdownPort.sendPort);

  // Wait for shutdown signal
  await shutdownPort.first;
  shutdownPort.close();
  await server.close();
}

/// Represents a cluster of Sparky server instances running across isolates.
///
/// Returned by [Sparky.serve]. Use [close] to gracefully shut down
/// all isolates.
final class SparkyCluster {
  final List<Isolate> _isolates;
  final List<SendPort> _shutdownPorts;
  final Sparky _mainServer;

  SparkyCluster._({
    required List<Isolate> isolates,
    required List<SendPort> shutdownPorts,
    required Sparky mainServer,
  })  : _isolates = isolates,
        _shutdownPorts = shutdownPorts,
        _mainServer = mainServer;

  /// The actual port the cluster is listening on.
  int get port => _mainServer.actualPort;

  /// Gracefully shuts down all isolates and the main server.
  ///
  /// Sends a shutdown signal to each worker and waits up to 5 seconds
  /// for graceful termination before force-killing.
  Future<void> close() async {
    final exitFutures = <Future<void>>[];

    for (var i = 0; i < _isolates.length; i++) {
      final exitPort = ReceivePort();
      _isolates[i].addOnExitListener(exitPort.sendPort);
      _shutdownPorts[i].send(null);

      exitFutures.add(
        exitPort.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _isolates[i].kill(priority: Isolate.immediate);
          },
        ).whenComplete(exitPort.close),
      );
    }

    await Future.wait(exitFutures);
    await _mainServer.close();
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
