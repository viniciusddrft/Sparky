// @author viniciusddrft

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sparky/src/multipart/multipart.dart';

/// Thrown when a request body exceeds the configured size limit.
final class BodyTooLargeException implements Exception {
  final int maxBytes;

  const BodyTooLargeException(this.maxBytes);

  @override
  String toString() => 'BodyTooLargeException(maxBytes: $maxBytes)';
}

/// Typed wrapper around [HttpRequest] that Sparky hands to every middleware,
/// guard, and route handler.
///
/// Holds all per-request state (path params, DI container, body cache,
/// request id, cancellation flag) on the instance itself — no Expandos — and
/// exposes a small, IDE-discoverable surface. When you need something that
/// isn't delegated here, reach through [raw] (e.g. `request.raw.response`
/// is also reachable as [response] for convenience).
final class SparkyRequest {
  /// The underlying [HttpRequest] from `dart:io`. Escape hatch for things
  /// not exposed on [SparkyRequest] itself.
  final HttpRequest raw;

  /// Unified body-reading namespace. See [RequestBody].
  late final RequestBody body = RequestBody._(this);

  /// Path parameters extracted from dynamic route matching (e.g. `:id`).
  /// Populated by the server after route resolution.
  Map<String, String> pathParams = const {};

  /// Short identifier assigned to this request by Sparky (8 hex chars).
  ///
  /// Unique within the current isolate. Empty before the server has assigned
  /// an ID; handlers, guards, and `pipelineAfter` always see a populated value.
  String requestId = '';

  int? _maxBodySize;
  bool _cancelled = false;
  final Map<Type, Object> _di = {};

  /// Wraps [raw] in a Sparky-flavored request. The server constructs one per
  /// inbound request; test code may construct its own when needed.
  SparkyRequest(this.raw);

  // ── HttpRequest delegates ────────────────────────────────────────────────

  /// HTTP method (`GET`, `POST`, ...).
  String get method => raw.method;

  /// Request URI (path + query).
  Uri get uri => raw.uri;

  /// The URI the client originally requested, before any server-side rewrites.
  Uri get requestedUri => raw.requestedUri;

  /// Incoming request headers.
  HttpHeaders get headers => raw.headers;

  /// Cookies parsed from the request's `Cookie` header.
  List<Cookie> get cookies => raw.cookies;

  /// `Content-Length` header value, or `-1` when unknown.
  int get contentLength => raw.contentLength;

  /// Connection metadata (remote address, port).
  HttpConnectionInfo? get connectionInfo => raw.connectionInfo;

  /// The outgoing response object. Pipeline middlewares use this to set
  /// headers or cookies directly (CORS, security headers, CSRF cookie). Do
  /// not call `.close()` — Sparky owns the response lifecycle.
  HttpResponse get response => raw.response;

  // ── Per-request state ────────────────────────────────────────────────────

  /// Whether this request was cancelled due to a timeout.
  ///
  /// Long-running handlers should check this periodically and bail out early
  /// to avoid wasted work after the client has already received a 408.
  bool get isCancelled => _cancelled;

  /// Marks the request as cancelled. Called by the server on timeout.
  void markCancelled() => _cancelled = true;

  /// Sets the maximum allowed body size (bytes) for subsequent body reads.
  void setMaxBodySize(int maxBytes) => _maxBodySize = maxBytes;

  /// Pre-reads and validates the body against [maxBytes]. Throws
  /// [BodyTooLargeException] when exceeded.
  Future<void> preloadBodyWithLimit(int maxBytes) async {
    _maxBodySize = maxBytes;
    await body.bytes();
  }

  // ── Dependency injection ─────────────────────────────────────────────────

  /// Stores a value of type [T] in the request's DI container.
  ///
  /// Use this in guards or pipeline middlewares to inject dependencies that
  /// downstream handlers can access via [read]. Overwrites any existing
  /// value of the same type — use [tryRead] first if you need to check.
  void provide<T extends Object>(T value) => _di[T] = value;

  /// Retrieves a value of type [T] previously stored via [provide].
  ///
  /// Throws [StateError] if no value of type [T] has been provided. Use
  /// [tryRead] for a null-safe alternative.
  T read<T extends Object>() {
    final v = _di[T];
    if (v == null) {
      throw StateError('No instance of type $T has been provided on this '
          'request. Call request.provide<$T>(value) first.');
    }
    return v as T;
  }

  /// Null-safe variant of [read].
  T? tryRead<T extends Object>() => _di[T] as T?;

  // ── Cookies ──────────────────────────────────────────────────────────────

  /// Returns the cookie with the given [name], or `null` if not present.
  Cookie? getCookie(String name) {
    for (final cookie in cookies) {
      if (cookie.name == name) return cookie;
    }
    return null;
  }

  // ── Content negotiation ──────────────────────────────────────────────────

  /// Returns `true` if the client accepts [mimeType] per its `Accept` header.
  ///
  /// Also returns `true` if the client accepts `*/*` or a matching type
  /// wildcard (e.g. `text/*`).
  bool accepts(String mimeType) => preferredType([mimeType]) != null;

  /// Convenience — `true` if the client accepts JSON.
  bool get acceptsJson => accepts('application/json');

  /// Convenience — `true` if the client accepts HTML.
  bool get acceptsHtml => accepts('text/html');

  /// Convenience — `true` if the client accepts plain text.
  bool get acceptsText => accepts('text/plain');

  /// Returns the best-matching MIME type from [available] based on the
  /// client's `Accept` header, or `null` if none match.
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
}

/// Unified body-reading namespace exposed via [SparkyRequest.body].
///
/// Each method consumes the stream only once and caches the result, so
/// mixing calls (e.g. [text] then [json]) is safe. [multipart] reads the
/// raw stream directly and does not share the text/bytes cache.
final class RequestBody {
  final SparkyRequest _request;
  String? _cachedText;
  Uint8List? _cachedBytes;

  RequestBody._(this._request);

  /// Reads the body as a UTF-8 string.
  Future<String> text() async {
    final cachedText = _cachedText;
    if (cachedText != null) return cachedText;
    final raw = await bytes();
    final content = utf8.decode(raw, allowMalformed: true);
    _cachedText = content;
    return content;
  }

  /// Reads the body as raw bytes.
  ///
  /// Unlike [text], this preserves binary data without UTF-8 decoding. Used
  /// internally by [multipart] is **not** true — multipart reads directly
  /// from the raw stream.
  Future<Uint8List> bytes() async {
    final cached = _cachedBytes;
    final max = _request._maxBodySize;
    if (cached != null) {
      if (max != null && cached.length > max) {
        throw BodyTooLargeException(max);
      }
      return cached;
    }

    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in _request.raw) {
      total += chunk.length;
      if (max != null && total > max) {
        throw BodyTooLargeException(max);
      }
      builder.add(chunk);
    }
    final result = builder.takeBytes();
    _cachedBytes = result;
    return result;
  }

  /// Parses the body as JSON and returns a `Map<String, dynamic>`.
  ///
  /// Returns an empty map when the body is empty or decodes to a non-object
  /// JSON value (array, scalar).
  Future<Map<String, dynamic>> json() async {
    final content = await text();
    if (content.isEmpty) return {};
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  /// Parses a URL-encoded form body (`application/x-www-form-urlencoded`).
  Future<Map<String, String>> form() async {
    final content = await text();
    if (content.isEmpty) return {};
    return Uri.splitQueryString(content);
  }

  /// Parses a `multipart/form-data` body into fields and files.
  ///
  /// Binary-safe: file uploads keep their exact bytes.
  ///
  /// ```dart
  /// final form = await request.body.multipart();
  /// final name = form.fields['name'];
  /// final avatar = form.files['avatar'];
  /// if (avatar != null) {
  ///   await File('uploads/${avatar.filename}').writeAsBytes(avatar.bytes);
  /// }
  /// ```
  ///
  /// Returns [MultipartData.empty] if the request is not
  /// `multipart/form-data` or has no boundary. Reads the raw stream directly,
  /// so calling this after [text] or [bytes] will yield an empty result.
  Future<MultipartData> multipart() async {
    final contentTypeHeader = _request.headers.value('content-type');
    final boundary = extractBoundary(contentTypeHeader);
    if (boundary == null) return const MultipartData.empty();
    return MultipartParser(_request.raw, boundary).parse();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accept-header parsing helpers.
// ─────────────────────────────────────────────────────────────────────────────

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
