import 'dart:async';
import 'dart:convert';
import 'dart:io';

int _hash = 0;
Map<String, String> _cache = {};

extension RequestTools on HttpRequest {
  Future<Map<String, String>> getBodyParams() async {
    if (_hash == hashCode) return _cache;

    final content = await utf8.decoder.bind(this).join();
    final Map<String, String> values = {};

    for (var param in _extractAllKeys(content)) {
      values[param] = _extractValue(content, param);
    }

    _cache = values;
    _hash = hashCode;
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
    'Content-Disposition: form-data; name="$param"s*\r?\n\r?\n(.*?)\r?\n',
    multiLine: true,
    dotAll: true,
  );

  final match = pattern.firstMatch(input);
  return match != null ? match.group(1)?.trim() ?? '' : '';
}
