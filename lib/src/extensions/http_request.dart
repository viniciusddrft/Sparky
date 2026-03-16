import 'dart:async';
import 'dart:convert';
import 'dart:io';

final Expando<String> _rawBodyCache = Expando<String>();
final Expando<Map<String, String>> _pathParamsStore =
    Expando<Map<String, String>>();

extension RequestTools on HttpRequest {
  /// Path parameters extracted from dynamic route matching (e.g. `:id`).
  Map<String, String> get pathParams => _pathParamsStore[this] ?? const {};

  set pathParams(Map<String, String> params) => _pathParamsStore[this] = params;

  /// Reads the raw body string, caching it so the stream is only consumed once.
  Future<String> getRawBody() async {
    final cached = _rawBodyCache[this];
    if (cached != null) return cached;

    final content = await utf8.decoder.bind(this).join();
    _rawBodyCache[this] = content;
    return content;
  }

  /// Parses the body as JSON and returns a [Map<String, dynamic>].
  Future<Map<String, dynamic>> getJsonBody() async {
    final content = await getRawBody();
    if (content.isEmpty) return {};
    final decoded = json.decode(content);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  /// Parses a URL-encoded form body (application/x-www-form-urlencoded).
  Future<Map<String, String>> getFormData() async {
    final content = await getRawBody();
    if (content.isEmpty) return {};
    return Uri.splitQueryString(content);
  }

  /// Parses multipart/form-data body parameters.
  Future<Map<String, String>> getBodyParams() async {
    final content = await getRawBody();
    if (content.isEmpty) return {};

    final Map<String, String> values = {};
    for (var param in _extractAllKeys(content)) {
      values[param] = _extractValue(content, param);
    }
    return values;
  }
}

List<String> _extractAllKeys(String input) {
  final pattern = RegExp(
    'Content-Disposition: form-data; name="(.*?)"',
    multiLine: true,
    dotAll: true,
  );

  return pattern
      .allMatches(input)
      .map((match) => match.group(1) ?? '')
      .toList();
}

String _extractValue(String input, String param) {
  final pattern = RegExp(
    'Content-Disposition: form-data; name="$param"\\s*\r?\n\r?\n(.*?)\r?\n',
    multiLine: true,
    dotAll: true,
  );

  final match = pattern.firstMatch(input);
  return match != null ? match.group(1)?.trim() ?? '' : '';
}
