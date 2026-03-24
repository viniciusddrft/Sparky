// Author: viniciusddrft

import 'dart:io';
import 'package:sparky/src/response/response.dart';
import 'package:sparky/src/types/sparky_types.dart';

/// Configuration for rate limiting requests.
///
/// Limits the number of requests a client (identified by IP) can make
/// within a time [window]. Returns 429 Too Many Requests when exceeded.
///
/// ```dart
/// final limiter = RateLimiter(maxRequests: 100, window: Duration(minutes: 1));
///
/// Sparky.server(
///   pipelineBefore: Pipeline()..add(limiter.createMiddleware()),
///   routes: [...],
/// );
/// ```
final class RateLimiter {
  final int maxRequests;
  final Duration window;
  final int maxClients;
  final bool trustProxyHeaders;
  final String Function(HttpRequest request)? clientIdentifier;

  final _clients = <String, _ClientRecord>{};
  DateTime _lastCleanup = DateTime.now();

  RateLimiter({
    this.maxRequests = 60,
    this.window = const Duration(minutes: 1),
    this.maxClients = 10000,
    this.trustProxyHeaders = false,
    this.clientIdentifier,
  });

  /// Creates a rate limiting middleware that can be added to [pipelineBefore].
  ///
  /// Returns 429 Too Many Requests with a `Retry-After` header when the
  /// limit is exceeded. Returns `null` to continue the pipeline otherwise.
  MiddlewareNulable createMiddleware() {
    return (HttpRequest request) async {
      _cleanupIfNeeded();

      final ip = clientIdentifier?.call(request) ??
          _resolveClientIp(request, trustProxyHeaders: trustProxyHeaders);
      final now = DateTime.now();
      final record = _clients[ip];

      if (record == null || now.difference(record.windowStart) >= window) {
        if (!_clients.containsKey(ip)) {
          while (_clients.length >= maxClients) {
            _clients.remove(_clients.keys.first);
          }
        }
        _clients[ip] = _ClientRecord(windowStart: now, count: 1);
        return null;
      }

      record.count++;

      if (record.count > maxRequests) {
        final retryAfter =
            window.inSeconds - now.difference(record.windowStart).inSeconds;
        final normalizedRetryAfter = retryAfter < 1 ? 1 : retryAfter;

        return Response.tooManyRequests(
          body: {'error': 'Too many requests. Try again later.'},
          headers: {'Retry-After': normalizedRetryAfter.toString()},
        );
      }

      return null;
    };
  }

  void _cleanupIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastCleanup) < window) return;
    _lastCleanup = now;

    _clients.removeWhere(
      (_, record) => now.difference(record.windowStart) >= window,
    );
  }
}

String _resolveClientIp(HttpRequest request, {required bool trustProxyHeaders}) {
  if (trustProxyHeaders) {
    final forwardedFor = request.headers.value('x-forwarded-for');
    if (forwardedFor != null && forwardedFor.trim().isNotEmpty) {
      final firstIp = forwardedFor.split(',').first.trim();
      if (firstIp.isNotEmpty) return firstIp;
    }
  }
  return request.connectionInfo?.remoteAddress.address ?? 'unknown';
}

final class _ClientRecord {
  final DateTime windowStart;
  int count;

  _ClientRecord({required this.windowStart, required this.count});
}
