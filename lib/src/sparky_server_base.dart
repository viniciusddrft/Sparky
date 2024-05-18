// @author viniciusddrft

import 'package:sparky/src/types/sparky_types.dart';
import 'route/route_base.dart';

/// Main logic file of Sparky's operation.

part 'package:sparky/src/pipeline/pipeline.dart';

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
}
