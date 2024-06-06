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
      this.pipelineAfter,
      this.pipelineBefore});
  final List<Route> routes;
  final int port;
  final String ip;
  final Route? routeNotFound;
  final LogConfig logConfig;
  final LogType logType;
  final Pipeline? pipelineBefore, pipelineAfter;
  final cacheManager = _CacheManager();

  Future<Response?> runPipeline(Pipeline? pipeline, HttpRequest request) async {
    if (pipeline?.mids.isNotEmpty != null) {
      for (final mid in pipeline!.mids) {
        final response = await mid(request);
        if (response != null) {
          return response;
        }
      }
    }
    return null;
  }
}
