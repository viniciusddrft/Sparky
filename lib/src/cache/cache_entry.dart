import 'package:sparky/src/response/response.dart';

final class CacheEntry {
  final Response response;
  final int version;

  const CacheEntry({required this.response, required this.version});
}
