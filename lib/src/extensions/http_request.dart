import 'dart:async';
import 'dart:convert';
import 'dart:io';

final Expando<String> _rawBodyCache = Expando<String>();
final Expando<Map<String, String>> _pathParamsStore =
    Expando<Map<String, String>>();
final Expando<int> _maxBodySizeStore = Expando<int>();
final Expando<bool> _cancelledStore = Expando<bool>();

final class BodyTooLargeException implements Exception {
  final int maxBytes;

  const BodyTooLargeException(this.maxBytes);

  @override
  String toString() => 'BodyTooLargeException(maxBytes: $maxBytes)';
}

extension RequestTools on HttpRequest {
  /// Path parameters extracted from dynamic route matching (e.g. `:id`).
  Map<String, String> get pathParams => _pathParamsStore[this] ?? const {};

  set pathParams(Map<String, String> params) => _pathParamsStore[this] = params;

  /// Returns `true` if the client accepts the given MIME type.
  ///
  /// Checks the `Accept` header. Also returns `true` if the client
  /// accepts `*/*` or a matching type wildcard (e.g. `text/*`).
  bool accepts(String mimeType) {
    return preferredType([mimeType]) != null;
  }

  /// Returns the best matching MIME type from [available] based on the
  /// client's `Accept` header, or `null` if none match.
  ///
  /// ```dart
  /// final type = request.preferredType(['application/json', 'text/html']);
  /// ```
  String? preferredType(List<String> available) {
    final accept = headers.value(HttpHeaders.acceptHeader);
    if (available.isEmpty) return null;
    if (accept == null || accept.trim().isEmpty) {
      return available.firstOrNull;
    }

    final parsedAvailable = available
        .map(_parseMediaType)
        .whereType<_MediaType>()
        .toList(growable: false);
    if (parsedAvailable.isEmpty) return null;

    final ranges = _parseAcceptHeader(accept);
    if (ranges.isEmpty) {
      return available.firstOrNull;
    }

    _MatchResult? bestMatch;
    for (var i = 0; i < parsedAvailable.length; i++) {
      final candidate = parsedAvailable[i];
      for (final range in ranges) {
        if (!range.matches(candidate)) continue;
        final result = _MatchResult(
          availableIndex: i,
          quality: range.quality,
          specificity: range.specificity,
          acceptOrder: range.order,
        );
        if (bestMatch == null || result.isBetterThan(bestMatch)) {
          bestMatch = result;
        }
      }
    }

    return bestMatch != null ? available[bestMatch.availableIndex] : null;
  }

  /// Convenience getter — `true` if the client accepts JSON.
  bool get acceptsJson => accepts('application/json');

  /// Convenience getter — `true` if the client accepts HTML.
  bool get acceptsHtml => accepts('text/html');

  /// Convenience getter — `true` if the client accepts plain text.
  bool get acceptsText => accepts('text/plain');

  /// Whether this request was cancelled due to a timeout.
  ///
  /// Long-running handlers should check this periodically and bail out
  /// early to avoid wasted work after the client already received a 408.
  bool get isCancelled => _cancelledStore[this] ?? false;

  /// Marks this request as cancelled. Called internally by the server
  /// when [requestTimeout] is exceeded.
  void markCancelled() {
    _cancelledStore[this] = true;
  }

  /// Returns the cookie with the given [name], or `null` if not found.
  Cookie? getCookie(String name) {
    for (final cookie in cookies) {
      if (cookie.name == name) return cookie;
    }
    return null;
  }

  /// Reads the raw body string, caching it so the stream is only consumed once.
  Future<String> getRawBody() async {
    final cached = _rawBodyCache[this];
    if (cached != null) return cached;

    final content = await _readRawBodyWithLimit(this);
    _rawBodyCache[this] = content;
    return content;
  }

  /// Defines the maximum allowed request body size for subsequent body reads.
  ///
  /// This guard is enforced by [getRawBody], [getJsonBody], [getFormData] and
  /// [getBodyParams].
  void setMaxBodySize(int maxBytes) {
    _maxBodySizeStore[this] = maxBytes;
  }

  /// Pre-reads and validates body size against [maxBytes].
  ///
  /// If body is already cached, validation is still applied. Throws
  /// [BodyTooLargeException] when the limit is exceeded.
  Future<void> preloadBodyWithLimit(int maxBytes) async {
    setMaxBodySize(maxBytes);
    await _readRawBodyWithLimit(this);
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

Future<String> _readRawBodyWithLimit(HttpRequest request) async {
  final cached = _rawBodyCache[request];
  final maxBytes = _maxBodySizeStore[request];
  if (cached != null) {
    if (maxBytes != null && utf8.encode(cached).length > maxBytes) {
      throw BodyTooLargeException(maxBytes);
    }
    return cached;
  }

  final chunks = <int>[];
  var total = 0;
  await for (final chunk in request) {
    total += chunk.length;
    if (maxBytes != null && total > maxBytes) {
      throw BodyTooLargeException(maxBytes);
    }
    chunks.addAll(chunk);
  }
  final content = utf8.decode(chunks);
  _rawBodyCache[request] = content;
  return content;
}

List<_AcceptRange> _parseAcceptHeader(String headerValue) {
  final ranges = <_AcceptRange>[];
  final parts = headerValue.split(',');
  for (var i = 0; i < parts.length; i++) {
    final rawPart = parts[i].trim();
    if (rawPart.isEmpty) continue;
    final pieces = rawPart.split(';');
    final mediaType = _parseMediaType(pieces.first.trim());
    if (mediaType == null) continue;
    var quality = 1.0;
    for (final param in pieces.skip(1)) {
      final clean = param.trim();
      if (!clean.startsWith('q=')) continue;
      final parsed = double.tryParse(clean.substring(2).trim());
      if (parsed == null) continue;
      quality = parsed.clamp(0, 1).toDouble();
    }
    if (quality <= 0) continue;
    ranges.add(_AcceptRange(
      type: mediaType.type,
      subtype: mediaType.subtype,
      quality: quality,
      order: i,
    ));
  }
  return ranges;
}

_MediaType? _parseMediaType(String value) {
  final parts = value.split('/');
  if (parts.length != 2) return null;
  final type = parts[0].trim().toLowerCase();
  final subtype = parts[1].trim().toLowerCase();
  if (type.isEmpty || subtype.isEmpty) return null;
  return _MediaType(type, subtype);
}

final class _MediaType {
  final String type;
  final String subtype;

  const _MediaType(this.type, this.subtype);
}

final class _AcceptRange {
  final String type;
  final String subtype;
  final double quality;
  final int order;

  const _AcceptRange({
    required this.type,
    required this.subtype,
    required this.quality,
    required this.order,
  });

  bool matches(_MediaType candidate) {
    final typeMatch = type == '*' || type == candidate.type;
    final subtypeMatch = subtype == '*' || subtype == candidate.subtype;
    return typeMatch && subtypeMatch;
  }

  int get specificity {
    if (type == '*' && subtype == '*') return 0;
    if (subtype == '*') return 1;
    return 2;
  }
}

final class _MatchResult {
  final int availableIndex;
  final double quality;
  final int specificity;
  final int acceptOrder;

  const _MatchResult({
    required this.availableIndex,
    required this.quality,
    required this.specificity,
    required this.acceptOrder,
  });

  bool isBetterThan(_MatchResult other) {
    if (quality != other.quality) return quality > other.quality;
    if (specificity != other.specificity) return specificity > other.specificity;
    if (acceptOrder != other.acceptOrder) return acceptOrder < other.acceptOrder;
    return availableIndex < other.availableIndex;
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
