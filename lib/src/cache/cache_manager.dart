import 'package:sparky/sparky.dart';
import 'package:sparky/src/cache/cache_entry.dart';

final class CacheManager {
  final _cache = <Route, CacheEntry>{};

  bool verifyVersionCache(Route route) {
    return _cache.containsKey(route) &&
        _cache[route]!.version == route.versionCache;
  }

  Response getCache(Route route) {
    return _cache[route]!.response;
  }

  void saveCache(Route route, Response response) {
    _cache.addAll({
      route: CacheEntry(response: response, version: route.versionCache),
    });
  }
}
