import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sparky/src/multipart/multipart.dart';

final Expando<String> _rawBodyCache = Expando<String>();
final Expando<Map<String, String>> _pathParamsStore =
    Expando<Map<String, String>>();
final Expando<int> _maxBodySizeStore = Expando<int>();
final Expando<bool> _cancelledStore = Expando<bool>();
final Expando<Map<Type, Object>> _diStore = Expando<Map<Type, Object>>();
final Expando<Uint8List> _rawBodyBytesCache = Expando<Uint8List>();

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

  // ──────────────────────────────────────────────────────────────────
  // Dependency Injection
  // ──────────────────────────────────────────────────────────────────

  /// Stores a value of type [T] in the request's DI container.
  ///
  /// Use this in guards or pipeline middlewares to inject dependencies
  /// that downstream handlers can access via [read].
  ///
  /// ```dart
  /// // In a guard:
  /// Future<Response?> authGuard(HttpRequest request) async {
  ///   final user = await authenticate(request);
  ///   if (user == null) return const Response.unauthorized(body: 'Denied');
  ///   request.provide<User>(user);
  ///   return null;
  /// }
  ///
  /// // In a handler:
  /// final user = request.read<User>();
  /// ```
  void provide<T extends Object>(T value) {
    final store = _diStore[this] ?? {};
    store[T] = value;
    _diStore[this] = store;
  }

  /// Retrieves a value of type [T] previously stored via [provide].
  ///
  /// Throws [StateError] if no value of type [T] has been provided.
  /// Use [tryRead] for a null-safe alternative.
  T read<T extends Object>() {
    final store = _diStore[this];
    final value = store?[T];
    if (value == null) {
      throw StateError('No instance of type $T has been provided on this request. '
          'Call request.provide<$T>(value) first.');
    }
    return value as T;
  }

  /// Retrieves a value of type [T] previously stored via [provide],
  /// or `null` if not found.
  T? tryRead<T extends Object>() {
    final store = _diStore[this];
    return store?[T] as T?;
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

  /// Reads the raw body as bytes, caching for reuse.
  ///
  /// Unlike [getRawBody], this preserves binary data without
  /// UTF-8 decoding and is used internally by [getMultipartData].
  Future<Uint8List> getRawBodyBytes() async {
    final cached = _rawBodyBytesCache[this];
    if (cached != null) return cached;

    final bytes = await _readRawBodyBytesWithLimit(this);
    _rawBodyBytesCache[this] = bytes;
    return bytes;
  }

  /// Parses a `multipart/form-data` body into fields and files.
  ///
  /// This is a binary-safe parser that correctly handles file
  /// uploads with arbitrary binary content.
  ///
  /// ```dart
  /// final form = await request.getMultipartData();
  /// final name = form.fields['name'];
  /// final avatar = form.files['avatar'];
  /// if (avatar != null) {
  ///   await File('uploads/${avatar.filename}').writeAsBytes(avatar.bytes);
  /// }
  /// ```
  ///
  /// Returns [MultipartData.empty] if the request is not
  /// `multipart/form-data` or has no boundary.
  Future<MultipartData> getMultipartData() async {
    final contentTypeHeader = headers.value('content-type');
    final boundary = extractBoundary(contentTypeHeader);
    if (boundary == null) return const MultipartData.empty();

    return MultipartParser(this, boundary).parse();
  }

  /// Parses multipart/form-data body parameters (text fields only).
  ///
  /// **Deprecated**: Use [getMultipartData] instead, which also handles
  /// file uploads correctly with binary-safe parsing.
  @Deprecated('Use getMultipartData() for binary-safe multipart parsing')
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

  final bytes = await _readRawBodyBytesWithLimit(request);
  final content = utf8.decode(bytes, allowMalformed: true);
  _rawBodyCache[request] = content;
  return content;
}

Future<Uint8List> _readRawBodyBytesWithLimit(HttpRequest request) async {
  final cached = _rawBodyBytesCache[request];
  final maxBytes = _maxBodySizeStore[request];
  if (cached != null) {
    if (maxBytes != null && cached.length > maxBytes) {
      throw BodyTooLargeException(maxBytes);
    }
    return cached;
  }

  final builder = BytesBuilder(copy: false);
  var total = 0;
  await for (final chunk in request) {
    total += chunk.length;
    if (maxBytes != null && total > maxBytes) {
      throw BodyTooLargeException(maxBytes);
    }
    builder.add(chunk);
  }
  final bytes = builder.takeBytes();
  _rawBodyBytesCache[request] = bytes;
  return bytes;
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
