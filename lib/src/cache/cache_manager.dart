/// Manages the caching mechanism for routes.
///
/// Cache entries are keyed by both the [Route] and the HTTP method,
/// so GET and POST to the same route have independent caches.
///
/// Author: viniciusddrft
library;

import '../response/response.dart';
import '../route/route_base.dart';

/// Internal — not part of Sparky's public API.
///
/// Promoted from a private `_CacheManager` to a public class only because
/// `SparkyBase` (in another library) needs to reference the type. Not
/// re-exported via `package:sparky/sparky.dart`. Subject to change without
/// notice across minor versions.
final class CacheManager {
  final _cache = <_CacheKey, _CacheEntry>{};
  Duration? ttl;
  int? maxEntries;

  /// Verifies if the cached version of the route + method matches the current version.
  bool verifyVersionCache(Route route, String method) {
    _evictExpiredEntries();
    final key = _CacheKey(route, method);
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.version != route.versionCache) {
      _cache.remove(key);
      return false;
    }
    _touch(key, entry);
    return true;
  }

  /// Retrieves the cached response for the given route and method.
  Response getCache(Route route, String method) {
    final key = _CacheKey(route, method);
    final entry = _cache[key]!;
    _touch(key, entry);
    return entry.response;
  }

  /// Saves a new response to the cache for the given route and method.
  void saveCache(Route route, String method, Response response) {
    _evictExpiredEntries();
    final key = _CacheKey(route, method);
    if (maxEntries != null && !_cache.containsKey(key)) {
      while (_cache.length >= maxEntries!) {
        _cache.remove(_cache.keys.first);
      }
    }
    _cache[key] = _CacheEntry(response: response, version: route.versionCache);
  }

  void _evictExpiredEntries() {
    if (ttl == null) return;
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.difference(entry.createdAt) > ttl!);
  }

  void _touch(_CacheKey key, _CacheEntry entry) {
    _cache
      ..remove(key)
      ..[key] = entry;
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
  final DateTime createdAt;

  _CacheEntry({required this.response, required this.version})
      : createdAt = DateTime.now();
}
