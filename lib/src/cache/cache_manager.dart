/// Manages the caching mechanism for routes.
///
/// This class provides methods to verify cache versions, retrieve cached
/// responses, and save new cache entries. It ensures that the response for
/// a route is served from cache if the version matches, enhancing performance
/// by avoiding unnecessary processing.
///
/// Usage:
/// - `verifyVersionCache(route)`: Checks if the cache is valid for the given route.
/// - `getCache(route)`: Retrieves the cached response for the given route.
/// - `saveCache(route, response)`: Saves a new response to the cache for the given route.
///
/// Author: viniciusddrft

part of '../sparky_server_base.dart';

final class _CacheManager {
  final _cache = <Route, _CacheEntry>{};

  /// Verifies if the cached version of the route matches the current version.
  ///
  /// Returns `true` if the cache is valid, otherwise `false`.
  bool verifyVersionCache(Route route) {
    return _cache.containsKey(route) &&
        _cache[route]!.version == route.versionCache;
  }

  /// Retrieves the cached response for the given route.
  ///
  /// Assumes that the cache is valid. Ensure to call `verifyVersionCache` before using this method.
  Response getCache(Route route) {
    return _cache[route]!.response;
  }

  /// Saves a new response to the cache for the given route.
  ///
  /// Associates the route with the response and its current version.
  void saveCache(Route route, Response response) {
    _cache.addAll({
      route: _CacheEntry(response: response, version: route.versionCache),
    });
  }
}

/// Represents a cache entry containing the response and its version.
///
/// This class is used internally by the `_CacheManager` to manage cache entries.
final class _CacheEntry {
  final Response response;
  final int version;

  /// Constructs a `_CacheEntry` with the given response and version.
  const _CacheEntry({required this.response, required this.version});
}
