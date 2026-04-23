// @author viniciusddrft

import 'dart:io';
import 'package:sparky/sparky.dart';
import 'package:sparky/src/metrics/app_routes_bundle.dart';

import 'cache/cache_manager.dart';

/// Main logic file of Sparky's operation.

base class SparkyBase {
  /// Generative constructor callable from subclasses.
  ///
  /// Runtime knobs are grouped into four config objects:
  /// [server] (port/ip/shared/securityContext), [limits]
  /// (requestTimeout/maxBodySize), [cache] (ttl/maxEntries), and
  /// [compression] (enableGzip/gzipMinLength). Each defaults to its own
  /// `const` default constructor, so omitting them keeps prior behavior.
  SparkyBase({
    required List<Route> routes,
    OpenApiConfig? openApi,
    MetricsConfig? metrics,
    HealthCheckConfig? health,
    SchedulerConfig? scheduler,
    ServerOptions server = const ServerOptions(),
    LimitsConfig limits = const LimitsConfig(),
    CacheConfig cache = const CacheConfig(),
    CompressionConfig compression = const CompressionConfig(),
    this.routeNotFound,
    this.logConfig = LogConfig.showAndWriteLogs,
    this.logType = LogType.all,
    this.logFormat = LogFormat.text,
    this.logFilePath = 'logs.txt',
    this.pipelineBefore,
    this.pipelineAfter,
  })  : port = server.port,
        ip = server.ip,
        shared = server.shared,
        securityContext = server.securityContext,
        requestTimeout = limits.requestTimeout,
        maxBodySize = limits.maxBodySize,
        enableGzip = compression.enableGzip,
        gzipMinLength = compression.gzipMinLength,
        _appRoutes = AppRoutesBundle.merge(routes, openApi, metrics, health),
        _scheduler = scheduler != null ? Scheduler(scheduler) : null,
        _cacheManager = CacheManager()
          ..ttl = cache.ttl
          ..maxEntries = cache.maxEntries;

  final AppRoutesBundle _appRoutes;
  final Scheduler? _scheduler;

  /// Resolved routes (user routes + optional OpenAPI + optional `/metrics`).
  List<Route> get routes => _appRoutes.routes;

  /// In-process Prometheus metrics, or `null` when [MetricsConfig] was disabled.
  PrometheusMetrics? get prometheusMetrics => _appRoutes.prometheusMetrics;

  /// In-process scheduler, or `null` when [SchedulerConfig] was not provided.
  Scheduler? get scheduler => _scheduler;
  final int port;
  final bool shared;
  final String ip, logFilePath;
  final Route? routeNotFound;
  final LogConfig logConfig;
  final LogType logType;
  final LogFormat logFormat;
  final Pipeline? pipelineBefore, pipelineAfter;
  final SecurityContext? securityContext;
  final Duration? requestTimeout;
  final int? maxBodySize;
  final bool enableGzip;
  final int gzipMinLength;
  final CacheManager _cacheManager;

  /// Whether [route] + [method] has a valid cached response.
  bool isCached(Route route, String method) =>
      _cacheManager.verifyVersionCache(route, method);

  /// Returns the cached [Response] for [route] + [method].
  Response getCachedResponse(Route route, String method) =>
      _cacheManager.getCache(route, method);

  /// Stores [response] in the cache for [route] + [method].
  void cacheResponse(Route route, String method, Response response) =>
      _cacheManager.saveCache(route, method, response);

  Future<Response?> runPipeline(Pipeline? pipeline, SparkyRequest request) async {
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
