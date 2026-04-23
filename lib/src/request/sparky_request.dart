// @author viniciusddrft

import 'dart:async';
import 'dart:io';

import 'content_negotiation.dart';
import 'request_body.dart';

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
  late final RequestBody body = RequestBody.internal(this);

  /// Path parameters extracted from dynamic route matching (e.g. `:id`).
  /// Populated by the server after route resolution.
  Map<String, String> pathParams = const {};

  /// Short identifier assigned to this request by Sparky (8 hex chars).
  ///
  /// Unique within the current isolate. Empty before the server has assigned
  /// an ID; handlers, guards, and `pipelineAfter` always see a populated value.
  String requestId = '';

  /// Max allowed body size in bytes, or `null` for unbounded.
  ///
  /// `@nodoc` — package-internal: [RequestBody] reads this to enforce limits.
  /// Set via [setMaxBodySize] or [preloadBodyWithLimit] from user code.
  int? maxBodySize;

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
  void setMaxBodySize(int maxBytes) => maxBodySize = maxBytes;

  /// Pre-reads and validates the body against [maxBytes]. Throws
  /// [BodyTooLargeException] when exceeded.
  Future<void> preloadBodyWithLimit(int maxBytes) async {
    maxBodySize = maxBytes;
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
  String? preferredType(List<String> available) => preferredMimeType(
        headers.value(HttpHeaders.acceptHeader),
        available,
      );
}
