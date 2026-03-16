/// Manages the caching mechanism for routes.
///
/// Cache entries are keyed by both the [Route] and the HTTP method,
/// so GET and POST to the same route have independent caches.
///
/// Author: viniciusddrft

part of '../sparky_server_base.dart';

final class _CacheManager {
  final _cache = <_CacheKey, _CacheEntry>{};

  /// Verifies if the cached version of the route + method matches the current version.
  bool verifyVersionCache(Route route, String method) {
    final key = _CacheKey(route, method);
    return _cache.containsKey(key) &&
        _cache[key]!.version == route.versionCache;
  }

  /// Retrieves the cached response for the given route and method.
  Response getCache(Route route, String method) {
    return _cache[_CacheKey(route, method)]!.response;
  }

  /// Saves a new response to the cache for the given route and method.
  void saveCache(Route route, String method, Response response) {
    _cache[_CacheKey(route, method)] =
        _CacheEntry(response: response, version: route.versionCache);
  }
}

final class _CacheKey {
  final Route route;
  final String method;

  const _CacheKey(this.route, this.method);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CacheKey && route == other.route && method == other.method;

  @override
  int get hashCode => Object.hash(route, method);
}

final class _CacheEntry {
  final Response response;
  final int version;

  const _CacheEntry({required this.response, required this.version});
}
