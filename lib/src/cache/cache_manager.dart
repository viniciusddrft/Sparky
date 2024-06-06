part of '../sparky_server_base.dart';

final class _CacheManager {
  final _cache = <Route, _CacheEntry>{};

  bool verifyVersionCache(Route route) {
    return _cache.containsKey(route) &&
        _cache[route]!.version == route.versionCache;
  }

  Response getCache(Route route) {
    return _cache[route]!.response;
  }

  void saveCache(Route route, Response response) {
    _cache.addAll({
      route: _CacheEntry(response: response, version: route.versionCache),
    });
  }
}

final class _CacheEntry {
  final Response response;
  final int version;

  const _CacheEntry({required this.response, required this.version});
}
