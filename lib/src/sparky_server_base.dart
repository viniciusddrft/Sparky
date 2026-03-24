// @author viniciusddrft

import 'dart:io';
import 'package:sparky/sparky.dart';

/// Main logic file of Sparky's operation.

part 'package:sparky/src/pipeline/pipeline.dart';
part 'cache/cache_manager.dart';

base class SparkyBase {
  SparkyBase(
      {required this.routes,
      this.port = 8080,
      this.ip = '0.0.0.0',
      this.routeNotFound,
      this.logConfig = LogConfig.showAndWriteLogs,
      this.logType = LogType.all,
      this.logFilePath = 'logs.txt',
      this.pipelineAfter,
      this.pipelineBefore,
      this.securityContext,
      this.requestTimeout,
      this.maxBodySize,
      this.enableGzip = false,
      this.gzipMinLength = 0,
      /// Time-to-live for cached responses. Only applies to static routes
      /// (routes without `:param` segments). Dynamic routes are never cached
      /// because each path parameter combination would need its own entry.
      Duration? cacheTtl,

      /// Maximum number of entries in the response cache. When exceeded,
      /// the least recently used entry is evicted. Only static routes are cached.
      int? cacheMaxEntries})
      : _cacheManager = _CacheManager()
          ..ttl = cacheTtl
          ..maxEntries = cacheMaxEntries;
  final List<Route> routes;
  final int port;
  final String ip, logFilePath;
  final Route? routeNotFound;
  final LogConfig logConfig;
  final LogType logType;
  final Pipeline? pipelineBefore, pipelineAfter;
  final SecurityContext? securityContext;
  final Duration? requestTimeout;
  final int? maxBodySize;
  final bool enableGzip;
  final int gzipMinLength;
  final _CacheManager _cacheManager;

  /// Whether [route] + [method] has a valid cached response.
  bool isCached(Route route, String method) =>
      _cacheManager.verifyVersionCache(route, method);

  /// Returns the cached [Response] for [route] + [method].
  Response getCachedResponse(Route route, String method) =>
      _cacheManager.getCache(route, method);

  /// Stores [response] in the cache for [route] + [method].
  void cacheResponse(Route route, String method, Response response) =>
      _cacheManager.saveCache(route, method, response);

  Future<Response?> runPipeline(Pipeline? pipeline, HttpRequest request) async {
    if (pipeline != null && pipeline.mids.isNotEmpty) {
      for (final mid in pipeline.mids) {
        final response = await mid(request);
        if (response != null) {
          return response;
        }
      }
    }
    return null;
  }
}
