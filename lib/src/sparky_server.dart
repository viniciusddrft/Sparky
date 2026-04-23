// @author viniciusddrft

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:sparky/src/sparky_server_base.dart';
import 'package:sparky/src/types/sparky_types.dart';
import 'errors/sparky_error.dart';
import 'handler/error_body.dart';
import 'handler/error_response.dart';
import 'request/sparky_request.dart';
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
  ///
  /// Runtime knobs are grouped into four config objects — [server]
  /// (port/ip/shared/securityContext), [limits] (requestTimeout/maxBodySize),
  /// [cache] (ttl/maxEntries), and [compression] (enableGzip/gzipMinLength) —
  /// each with `const` defaults so simple setups stay concise.
  Sparky.single({
    required super.routes,
    super.openApi,
    super.metrics,
    super.health,
    super.scheduler,
    super.server,
    super.limits,
    super.cache,
    super.compression,
    super.routeNotFound,
    super.logConfig,
    super.logType,
    super.logFormat,
    super.logFilePath,
    super.pipelineBefore,
    super.pipelineAfter,
  }) {
    _init();
  }

  late final HttpServer _server;
  // Static HTTP routes: path -> (method -> route).
  late final Map<String, Map<String, Route>> _staticHttpRoutes;
  // Static WebSocket routes: path -> route.
  late final Map<String, Route> _staticWsRoutes;
  late final List<Route> _dynamicHttpRoutes;
  late final List<Route> _dynamicWsRoutes;
  StreamSubscription<HttpRequest>? _subscription;

  // Per-isolate monotonic counter for request IDs. 32-bit wrap is intentional:
  // IDs are scoped to a single isolate and need to be unique only across the
  // in-flight window, not forever.
  int _requestCounter = 0;

  String _nextRequestId() {
    _requestCounter = (_requestCounter + 1) & 0xFFFFFFFF;
    return _requestCounter.toRadixString(16).padLeft(8, '0');
  }

  void _init() {
    if (routes.isEmpty) {
      throw ErrorRouteEmpty();
    }

    final httpStatic = <String, Map<String, Route>>{};
    final wsStatic = <String, Route>{};
    final httpDynamic = <Route>[];
    final wsDynamic = <Route>[];

    for (final route in routes) {
      final isWs = !route.isHttpRoute;
      final isDynamic = route.isDynamic;

      if (isWs) {
        if (isDynamic) {
          for (final existing in wsDynamic) {
            if (existing.path == route.path) {
              throw RoutesRepeated.duplicate(route.path);
            }
          }
          for (final existing in httpDynamic) {
            if (existing.path == route.path) {
              throw RoutesRepeated.duplicate(route.path);
            }
          }
          wsDynamic.add(route);
        } else {
          if (wsStatic.containsKey(route.path) ||
              httpStatic.containsKey(route.path)) {
            throw RoutesRepeated.duplicate(route.path);
          }
          wsStatic[route.path] = route;
        }
        continue;
      }

      final methods = route.acceptedMethods;
      if (methods == null || methods.isEmpty) continue;

      if (!isDynamic) {
        if (wsStatic.containsKey(route.path)) {
          throw RoutesRepeated.duplicate(route.path);
        }
        final perMethod =
            httpStatic.putIfAbsent(route.path, () => <String, Route>{});
        for (final m in methods) {
          if (perMethod.containsKey(m.text)) {
            throw RoutesRepeated.duplicate('${m.text} ${route.path}');
          }
          perMethod[m.text] = route;
        }
      } else {
        for (final existing in wsDynamic) {
          if (existing.path == route.path) {
            throw RoutesRepeated.duplicate(route.path);
          }
        }
        for (final existing in httpDynamic) {
          if (existing.path != route.path) continue;
          final existingMethods = existing.acceptedMethods;
          if (existingMethods == null) continue;
          for (final m in methods) {
            if (existingMethods.any((em) => em.text == m.text)) {
              throw RoutesRepeated.duplicate('${m.text} ${route.path}');
            }
          }
        }
        httpDynamic.add(route);
      }
    }

    _staticHttpRoutes = httpStatic;
    _staticWsRoutes = wsStatic;
    _dynamicHttpRoutes = httpDynamic;
    _dynamicWsRoutes = wsDynamic;
    scheduler?.defaultOnError = (task, error, stack) =>
        _errorServerLog('[scheduler] ${task.name} failed: $error');
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

  /// Resolves a route for the given [path] and [method].
  ///
  /// Returns a record where:
  /// - `route` is the matched route, or `null` if no path matches or only the
  ///   path matches but the method doesn't.
  /// - `methodNotAllowed` is `true` when the path matched at least one route
  ///   but no route accepts [method] — caller should respond with 405.
  /// - `allowedMethods` lists the methods accepted on [path] when
  ///   `methodNotAllowed` is true (used to populate the `Allow` header per
  ///   RFC 7231 §6.5.5). Empty in all other cases.
  ///
  /// Path parameters are set on [request] only for the route that will be
  /// served (not for routes whose path matches but method doesn't).
  ({Route? route, bool methodNotAllowed, List<String> allowedMethods})
      _resolveRoute(String path, String method, SparkyRequest request) {
    final ws = _staticWsRoutes[path];
    if (ws != null) {
      return (route: ws, methodNotAllowed: false, allowedMethods: const []);
    }

    final byMethod = _staticHttpRoutes[path];
    if (byMethod != null) {
      final exact = byMethod[method];
      if (exact != null) {
        return (
          route: exact,
          methodNotAllowed: false,
          allowedMethods: const [],
        );
      }
      return (
        route: null,
        methodNotAllowed: true,
        allowedMethods: byMethod.keys.toList(),
      );
    }

    for (final route in _dynamicWsRoutes) {
      final params = route.matchPath(path);
      if (params != null) {
        request.pathParams = params;
        return (route: route, methodNotAllowed: false, allowedMethods: const []);
      }
    }

    final allowedFromDynamic = <String>{};
    for (final route in _dynamicHttpRoutes) {
      final params = route.matchPath(path);
      if (params == null) continue;
      final methods = route.acceptedMethods;
      if (methods == null) continue;
      if (methods.any((m) => m.text == method)) {
        request.pathParams = params;
        return (route: route, methodNotAllowed: false, allowedMethods: const []);
      }
      for (final m in methods) {
        allowedFromDynamic.add(m.text);
      }
    }

    if (allowedFromDynamic.isNotEmpty) {
      return (
        route: null,
        methodNotAllowed: true,
        allowedMethods: allowedFromDynamic.toList(),
      );
    }
    return (route: null, methodNotAllowed: false, allowedMethods: const []);
  }

  bool _isCacheableMethod(String method) => method == 'GET' || method == 'HEAD';

  Future<void> _start() async {
    _server = securityContext != null
        ? await HttpServer.bindSecure(ip, port, securityContext!,
            shared: shared)
        : await HttpServer.bind(ip, port, shared: shared);

    _openServerLog();
    scheduler?.start();

    _subscription = _server.listen(
      _handleRequest,
      onError: _errorServerLog,
      onDone: () {
        _file?.flush();
        _file?.close();
      },
    );
  }

  Future<void> _handleRequest(HttpRequest raw) async {
    final request = SparkyRequest(raw)..requestId = _nextRequestId();
    final pm = prometheusMetrics;
    pm?.requestStarted();
    final sw = Stopwatch()..start();
    var statusForMetrics = HttpStatus.internalServerError;

    try {
      var upgradedToWebSocket = false;

      if (maxBodySize != null) {
        request.setMaxBodySize(maxBodySize!);
        final contentLength = request.contentLength;
        if (contentLength > maxBodySize!) {
          throw BodyTooLargeException(maxBodySize!);
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
        final pipelineBeforeResponse =
            await runPipeline(pipelineBefore, request);

        final lookup = _resolveRoute(path, request.method, request);
        final route = lookup.route;

        if (WebSocketTransformer.isUpgradeRequest(request.raw) &&
            route != null &&
            !route.isHttpRoute) {
          final websocket = await WebSocketTransformer.upgrade(request.raw);
          route.middlewareWebSocket!(websocket);
          upgradedToWebSocket = true;
          return const Response.ok(body: '');
        }

        if (pipelineBeforeResponse != null) return pipelineBeforeResponse;

        // Cache only applies to static routes (no :param segments),
        // idempotent methods (GET, HEAD), and routes without guards
        // (guards evaluate per-request state, e.g. auth). Dynamic
        // routes and stream responses are intentionally excluded.
        final cacheable = route != null &&
            !route.isDynamic &&
            route.guards.isEmpty &&
            _isCacheableMethod(request.method);
        if (cacheable && isCached(route, request.method)) {
          return getCachedResponse(route, request.method);
        }

        final response = await _internalHandler(
          request,
          route,
          lookup.methodNotAllowed,
          lookup.allowedMethods,
        );
        if (cacheable && !response.isStream) {
          cacheResponse(route, request.method, response);
        }
        return response;
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
        statusForMetrics = HttpStatus.switchingProtocols;
        return;
      }

      await _writeResponse(request, routeResponse);
      await runPipeline(pipelineAfter, request);
      _requestServerLog(request, routeResponse, duration: sw.elapsed);
      statusForMetrics = routeResponse.status;
    } catch (e) {
      final info = errorInfoFor(
        e,
        request.uri.path,
        requestId: logFormat == LogFormat.json ? request.requestId : null,
      );
      _errorServerLog(info.logMessage);
      await writeErrorResponse(request, info);
      statusForMetrics = info.status;
    } finally {
      pm?.recordHttpRequest(
        method: request.method,
        path: request.uri.path,
        statusCode: statusForMetrics,
        elapsed: sw.elapsed,
      );
      pm?.requestFinished();
    }
  }

  Future<void> _writeResponse(
      SparkyRequest request, Response routeResponse) async {
    final response = request.raw.response;
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

    final acceptsGzip = request.headers[HttpHeaders.acceptEncodingHeader]
            ?.any((e) => e.contains('gzip')) ==
        true;

    if (routeResponse.isStream) {
      final stream = routeResponse.bodyStream!;
      final canGzip = enableGzip &&
          acceptsGzip &&
          _isCompressibleContentType(routeResponse.contentType);
      if (canGzip) {
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
          acceptsGzip &&
          !routeResponse.isBinary &&
          responseBytes.length >= gzipMinLength;
      if (canGzip) {
        response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
        response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        response.add(gzip.encode(responseBytes));
      } else {
        response.add(responseBytes);
      }
    }
    await response.close();
  }

  Future<Response> _internalHandler(
    SparkyRequest request,
    Route? route,
    bool methodNotAllowed,
    List<String> allowedMethods,
  ) async {
    if (route != null) {
      for (final guard in route.guards) {
        final guardResponse = await guard(request);
        if (guardResponse != null) return guardResponse;
      }
      return route.middleware!(request);
    }

    if (methodNotAllowed) {
      return Response.methodNotAllowed(
        body: ErrorBody.toJson(HttpStatus.methodNotAllowed, 'Method Not Allowed'),
        headers: {'Allow': allowedMethods.join(', ')},
      );
    }

    if (routeNotFound?.middleware != null) {
      return routeNotFound!.middleware!(request);
    }
    return Response.notFound(
        body: ErrorBody.toJson(HttpStatus.notFound, 'Not Found'));
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
    await scheduler?.stop();
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
