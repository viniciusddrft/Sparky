// @author viniciusddrft

import 'dart:io';

/// Network/socket-level options for [Sparky.single].
///
/// Groups the "where do I bind" knobs so callers don't have to pass four
/// unrelated top-level parameters.
///
/// ```dart
/// Sparky.single(
///   routes: [...],
///   server: ServerOptions(port: 8080, shared: true),
/// );
/// ```
///
/// When passed, fields here win over the top-level `port` / `ip` / `shared` /
/// `securityContext` shortcuts on [Sparky.single].
final class ServerOptions {
  /// TCP port to bind. Use `0` to let the OS pick a free port.
  final int port;

  /// Interface to bind (`0.0.0.0` = all IPv4 interfaces).
  final String ip;

  /// Allow multiple isolates to bind the same port (required for cluster mode).
  final bool shared;

  /// Enables HTTPS when non-null. Loaded once per server instance.
  final SecurityContext? securityContext;

  const ServerOptions({
    this.port = 8080,
    this.ip = '0.0.0.0',
    this.shared = false,
    this.securityContext,
  });
}

/// Per-request resource limits.
///
/// Applies to every inbound request. Exceeding either limit terminates the
/// request early with the appropriate status (408 for [requestTimeout], 413
/// for [maxBodySize]).
final class LimitsConfig {
  /// Hard cap on total handler latency. `null` disables the check.
  final Duration? requestTimeout;

  /// Max body size in bytes. `null` disables the check.
  final int? maxBodySize;

  const LimitsConfig({this.requestTimeout, this.maxBodySize});
}

/// Response cache configuration.
///
/// Only applies to static routes (no `:param` segments) on idempotent methods
/// (GET / HEAD) with no guards. Dynamic routes, mutating methods, and guarded
/// routes are never cached.
final class CacheConfig {
  /// How long a cached response stays valid. `null` disables caching.
  final Duration? ttl;

  /// Max number of cached entries. LRU eviction when exceeded.
  final int? maxEntries;

  const CacheConfig({this.ttl, this.maxEntries});
}

/// Response compression configuration.
///
/// Applies gzip to responses whose content type is compressible and whose
/// body is at least [gzipMinLength] bytes. Clients must advertise
/// `Accept-Encoding: gzip`.
final class CompressionConfig {
  /// Master switch for gzip.
  final bool enableGzip;

  /// Minimum body size (in bytes) before gzip is applied. Streamed responses
  /// ignore this threshold.
  final int gzipMinLength;

  const CompressionConfig({
    this.enableGzip = false,
    this.gzipMinLength = 0,
  });
}
