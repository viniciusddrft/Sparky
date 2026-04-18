// @author viniciusddrft

import 'package:sparky/src/health/health_check.dart';
import 'package:sparky/src/health/health_routes.dart';
import 'package:sparky/src/openapi/openapi_routes.dart';
import 'package:sparky/src/openapi/openapi_types.dart';
import 'package:sparky/src/response/response.dart';
import 'package:sparky/src/route/route_base.dart';
import 'package:sparky/src/route/route_http.dart';

import 'metrics_config.dart';
import 'prometheus_metrics.dart';

/// Merges OpenAPI routes, health endpoints and the optional Prometheus scrape
/// route into one list.
final class AppRoutesBundle {
  AppRoutesBundle._(this.routes, this.prometheusMetrics);

  final List<Route> routes;
  final PrometheusMetrics? prometheusMetrics;

  factory AppRoutesBundle.merge(
    List<Route> userRoutes,
    OpenApiConfig? openApi,
    MetricsConfig? metrics,
    HealthCheckConfig? health,
  ) {
    var list = mergeOpenApiRoutes(userRoutes, openApi);
    list = mergeHealthRoutes(list, health);
    PrometheusMetrics? pm;
    if (metrics != null && metrics.enabled) {
      pm = PrometheusMetrics(
        namespace: metrics.namespace,
        durationBucketsSeconds: metrics.durationBucketsSeconds,
        ignorePaths: metrics.effectiveIgnorePaths,
      );
      final scrapePath = metrics.path;
      final collector = pm;
      final authGuard = metrics.authGuard;
      list = [
        ...list,
        RouteHttp.get(
          scrapePath,
          guards: [if (authGuard != null) authGuard],
          middleware: (_) async => Response.ok(
            body: collector.formatPrometheusText(),
            headers: const {
              'Content-Type': 'text/plain; version=0.0.4; charset=utf-8',
            },
          ),
        ),
      ];
    }
    return AppRoutesBundle._(list, pm);
  }
}
