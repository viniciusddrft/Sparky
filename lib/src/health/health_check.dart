// @author viniciusddrft

import 'dart:async';

import '../types/sparky_types.dart';

/// Health status reported by a single check or the overall endpoint.
///
/// Mapping to HTTP status codes in [HealthCheckConfig]:
/// - [up] and [degraded] → `200 OK`
/// - [down] → `503 Service Unavailable`
enum HealthStatus {
  up('UP'),
  degraded('DEGRADED'),
  down('DOWN');

  const HealthStatus(this.text);
  final String text;
}

/// Result returned by a [HealthCheck] function.
///
/// Use [HealthCheckResult.up] / [HealthCheckResult.down] / [HealthCheckResult.degraded]
/// for the common cases. [details] is serialized as-is under the check name in the
/// JSON body, so keep it to values encodable by `json.encode` (String, num, bool,
/// List, Map).
final class HealthCheckResult {
  final HealthStatus status;
  final String? message;
  final Map<String, Object?>? details;

  const HealthCheckResult({
    required this.status,
    this.message,
    this.details,
  });

  const HealthCheckResult.up({String? message, Map<String, Object?>? details})
      : this(status: HealthStatus.up, message: message, details: details);

  const HealthCheckResult.down({String? message, Map<String, Object?>? details})
      : this(status: HealthStatus.down, message: message, details: details);

  const HealthCheckResult.degraded({
    String? message,
    Map<String, Object?>? details,
  }) : this(status: HealthStatus.degraded, message: message, details: details);
}

/// A single health probe.
///
/// Return [HealthCheckResult.up] for healthy dependencies, [HealthCheckResult.down]
/// for hard failures. The scheduler runs each check in parallel with a timeout
/// ([HealthCheckConfig.checkTimeout]); throwing maps to [HealthStatus.down] with
/// the exception's `toString` as `message`.
typedef HealthCheck = FutureOr<HealthCheckResult> Function();

/// Configuration for the built-in `/health` (liveness) and `/ready` (readiness)
/// endpoints.
///
/// Follow the Kubernetes probe semantics:
/// - **Liveness** (`/health`): answers "is the process alive?" — keep it cheap,
///   no external dependencies, restart the pod if it fails.
/// - **Readiness** (`/ready`): answers "can it serve traffic?" — run against
///   databases, caches, downstream APIs. A failure temporarily removes the pod
///   from the service load balancer without restarting it.
///
/// Both endpoints return a JSON body with `status` and `checks`. The overall
/// status is the worst individual status ([HealthStatus.down] > [HealthStatus.degraded]
/// > [HealthStatus.up]). HTTP `200` when healthy/degraded, HTTP `503` when any
/// check is down.
///
/// Example:
/// ```dart
/// Sparky.single(
///   health: HealthCheckConfig(
///     readinessChecks: {
///       'db': () async {
///         final ok = await db.ping();
///         return ok ? HealthCheckResult.up() : HealthCheckResult.down();
///       },
///     },
///   ),
///   routes: [...],
/// );
/// ```
final class HealthCheckConfig {
  /// When false, no routes are registered.
  final bool enabled;

  /// Path for the liveness endpoint.
  final String livenessPath;

  /// Path for the readiness endpoint.
  final String readinessPath;

  /// Checks executed on `GET /health`. Typically empty — liveness should not
  /// depend on external systems.
  final Map<String, HealthCheck> livenessChecks;

  /// Checks executed on `GET /ready`.
  final Map<String, HealthCheck> readinessChecks;

  /// Per-check timeout. A check that does not complete in this window is
  /// reported as [HealthStatus.down] with message `"timeout"`.
  final Duration checkTimeout;

  /// Optional guard applied to both endpoints. Useful to require a Bearer
  /// token for cluster-internal probes without exposing dependency state
  /// publicly.
  final MiddlewareNullable? authGuard;

  /// When `true`, readiness responds with HTTP `503` for [HealthStatus.degraded]
  /// in addition to [HealthStatus.down]. Defaults to `false`.
  final bool failReadinessOnDegraded;

  const HealthCheckConfig({
    this.enabled = true,
    this.livenessPath = '/health',
    this.readinessPath = '/ready',
    this.livenessChecks = const {},
    this.readinessChecks = const {},
    this.checkTimeout = const Duration(seconds: 5),
    this.authGuard,
    this.failReadinessOnDegraded = false,
  }) : assert(livenessPath != readinessPath,
            'livenessPath and readinessPath must differ');
}

/// Worst-case aggregation: any DOWN → DOWN; else any DEGRADED → DEGRADED; else UP.
HealthStatus aggregateHealthStatus(Iterable<HealthStatus> statuses) {
  var worst = HealthStatus.up;
  for (final s in statuses) {
    if (s == HealthStatus.down) return HealthStatus.down;
    if (s == HealthStatus.degraded) worst = HealthStatus.degraded;
  }
  return worst;
}
