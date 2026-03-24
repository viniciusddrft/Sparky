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
      Duration? cacheTtl,
      int? cacheMaxEntries})
      : cacheManager = _CacheManager()
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
  // ignore: library_private_types_in_public_api
  final _CacheManager cacheManager;

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
