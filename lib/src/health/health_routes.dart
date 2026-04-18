// @author viniciusddrft

import 'dart:async';
import 'dart:io';

import '../response/response.dart';
import '../route/route_base.dart';
import '../route/route_http.dart';
import 'health_check.dart';

/// Appends liveness/readiness routes when [config] is enabled.
///
/// Returns [routes] unchanged when [config] is null or disabled. New routes are
/// appended last so they win on path collision with user routes, matching the
/// behavior of OpenAPI and metrics routes.
List<Route> mergeHealthRoutes(List<Route> routes, HealthCheckConfig? config) {
  if (config == null || !config.enabled) return routes;

  final guards = [if (config.authGuard != null) config.authGuard!];

  return [
    ...routes,
    RouteHttp.get(
      config.livenessPath,
      guards: guards,
      middleware: (_) => _runChecks(
        config.livenessChecks,
        config.checkTimeout,
        failOnDegraded: false,
      ),
    ),
    RouteHttp.get(
      config.readinessPath,
      guards: guards,
      middleware: (_) => _runChecks(
        config.readinessChecks,
        config.checkTimeout,
        failOnDegraded: config.failReadinessOnDegraded,
      ),
    ),
  ];
}

Future<Response> _runChecks(
  Map<String, HealthCheck> checks,
  Duration timeout, {
  required bool failOnDegraded,
}) async {
  final names = checks.keys.toList();
  final futures = [
    for (final name in names) _runOne(checks[name]!, timeout),
  ];
  final results = await Future.wait(futures);

  final body = <String, Object?>{};
  final checkBodies = <String, Object?>{};
  final statuses = <HealthStatus>[];

  for (var i = 0; i < names.length; i++) {
    final name = names[i];
    final result = results[i];
    statuses.add(result.status);
    final entry = <String, Object?>{
      'status': result.status.text,
    };
    if (result.message != null) entry['message'] = result.message;
    if (result.details != null) entry['details'] = result.details;
    checkBodies[name] = entry;
  }

  final overall = aggregateHealthStatus(statuses);
  body['status'] = overall.text;
  if (checkBodies.isNotEmpty) body['checks'] = checkBodies;

  final unhealthy = overall == HealthStatus.down ||
      (failOnDegraded && overall == HealthStatus.degraded);

  if (unhealthy) {
    return Response.serviceUnavailable(
      body: body,
      contentType: ContentType.json,
    );
  }
  return Response.ok(body: body, contentType: ContentType.json);
}

Future<HealthCheckResult> _runOne(
  HealthCheck check,
  Duration timeout,
) async {
  try {
    final future = Future<HealthCheckResult>.sync(() async => await check());
    return await future.timeout(
      timeout,
      onTimeout: () => const HealthCheckResult.down(message: 'timeout'),
    );
  } catch (e) {
    return HealthCheckResult.down(message: e.toString());
  }
}
