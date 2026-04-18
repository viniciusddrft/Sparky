// @author viniciusddrft

import '../types/sparky_types.dart';

/// Enables a Prometheus text exposition endpoint and HTTP request metrics.
///
/// Pass to [Sparky.single] as `metrics`. The endpoint is registered as a normal
/// `GET` route (after your routes), so it wins on path collision like OpenAPI.
///
/// Histogram buckets drive **p50 / p95 / p99** in Prometheus via
/// `histogram_quantile(0.95, sum(rate(sparky_http_request_duration_seconds_bucket[5m])) by (le, method))`
/// (adjust metric prefix to [namespace]).
final class MetricsConfig {
  /// When false, no route is added and no metrics are collected.
  final bool enabled;

  /// Path for `GET` scrape (Prometheus `metrics_path`).
  final String path;

  /// Metric name prefix (e.g. `sparky` → `sparky_http_requests_total`).
  final String namespace;

  /// Upper bounds in **seconds** for [histogram](https://prometheus.io/docs/concepts/metric_types/#histogram).
  ///
  /// A final `+Inf` bucket is added automatically.
  final List<double> durationBucketsSeconds;

  /// Request paths for which **no** samples are recorded (e.g. noisy probes).
  ///
  /// [path] is always ignored. Use normalized paths (no query); comparison is exact.
  final Set<String> ignorePaths;

  /// Optional guard applied to the scrape route.
  ///
  /// Return a non-null [Response] to deny access (typical for Bearer/IP
  /// allowlists). The scrape endpoint exposes request counts and latency
  /// histograms, so production deployments should protect it — either with
  /// this guard or by binding Sparky to an internal interface.
  final MiddlewareNullable? authGuard;

  MetricsConfig({
    this.enabled = true,
    this.path = '/metrics',
    this.namespace = 'sparky',
    this.durationBucketsSeconds = const [
      0.005,
      0.01,
      0.025,
      0.05,
      0.1,
      0.25,
      0.5,
      1.0,
      2.5,
      5.0,
      10.0,
    ],
    Set<String>? ignorePaths,
    this.authGuard,
  })  : ignorePaths = ignorePaths ?? const {} {
    assert(path.startsWith('/'), 'path must start with /');
  }

  Set<String> get effectiveIgnorePaths => {...ignorePaths, path};
}
