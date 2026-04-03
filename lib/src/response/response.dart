// Author: viniciusddrft

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sparky/src/sse/sse.dart';

/// This class handles responses, with some constructors already configured with request code.
///
/// The [body] field accepts any [Object] (String, Map, List, etc.).
/// Non-String values are automatically serialized to JSON.
final class Response {
  final int status;
  final Object _body;
  final ContentType? contentType;
  final Map<String, String>? headers;
  final List<Cookie>? cookies;

  /// Returns the body as a String. Non-String values are JSON-encoded.
  String get body {
    if (_body is Stream<List<int>>) {
      throw StateError('Stream body cannot be represented as String');
    }
    return _body is String ? _body : json.encode(_body);
  }

  /// Returns the body as bytes.
  ///
  /// - `List<int>` payloads are returned as-is (for binary responses).
  /// - String/JSON payloads are UTF-8 encoded.
  Uint8List get bodyBytes {
    final body = _body;
    if (body is Stream<List<int>>) {
      throw StateError('Stream body cannot be represented as bytes eagerly');
    }
    if (body is List<int>) {
      return Uint8List.fromList(body);
    }
    return Uint8List.fromList(utf8.encode(this.body));
  }

  /// Returns `true` when body is raw bytes.
  bool get isBinary => _body is List<int>;

  /// Returns `true` when body is a byte stream.
  bool get isStream => _body is Stream<List<int>>;

  /// Returns body stream when body is [Stream<List<int>>], otherwise `null`.
  Stream<List<int>>? get bodyStream =>
      _body is Stream<List<int>> ? _body : null;

  const Response(
      {required int statusCode,
      required Object body,
      this.contentType,
      this.headers, this.cookies})
      : status = statusCode,
        _body = body;

  /// Server-Sent Events (SSE) response.
  ///
  /// Converts a stream of [SseEvent]s into a properly formatted
  /// `text/event-stream` response with `Cache-Control: no-cache`.
  ///
  /// ```dart
  /// final events = Stream.periodic(
  ///   const Duration(seconds: 1),
  ///   (i) => SseEvent(data: 'tick $i', id: '$i'),
  /// ).take(10);
  /// return Response.sse(events);
  /// ```
  ///
  /// See [SseEvent] for the event format.
  Response.sse(
    Stream<SseEvent> events, {
    Map<String, String>? headers,
    this.cookies,
  })  : status = HttpStatus.ok,
        contentType = ContentType('text', 'event-stream', charset: 'utf-8'),
        headers = {
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          if (headers != null) ...headers,
        },
        _body = events
            .map((event) => event.encode())
            .map((text) => utf8.encode(text));

  /// Streaming byte response.
  ///
  /// Use this for large file downloads, proxied responses, or any
  /// scenario where the body should be piped without buffering.
  ///
  /// ```dart
  /// final file = File('large-report.csv');
  /// return Response.stream(
  ///   body: file.openRead(),
  ///   contentType: ContentType('text', 'csv'),
  ///   headers: {
  ///     'Content-Disposition': 'attachment; filename="report.csv"',
  ///   },
  /// );
  /// ```
  const Response.stream({
    required Stream<List<int>> body,
    int statusCode = HttpStatus.ok,
    this.contentType,
    this.headers,
    this.cookies,
  })  : status = statusCode,
        _body = body;

  /// Request Success
  const Response.ok({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.ok,
        _body = body;

  /// Request Not Found
  const Response.notFound(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notFound,
        _body = body;

  /// Request Method Not Allowed
  const Response.methodNotAllowed(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.methodNotAllowed,
        _body = body;

  /// Request Bad Request
  const Response.badRequest(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.badRequest,
        _body = body;

  /// Request Accepted
  const Response.accepted(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.accepted,
        _body = body;

  /// Request Unauthorized
  const Response.unauthorized(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.unauthorized,
        _body = body;

  /// Request Forbidden
  const Response.forbidden(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.forbidden,
        _body = body;

  /// Request MovedTemporarily
  const Response.movedTemporarily(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.movedTemporarily,
        _body = body;

  /// Request MovedPermanently
  const Response.movedPermanently(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.movedPermanently,
        _body = body;

  /// Request Created
  const Response.created({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.created,
        _body = body;

  /// Request InternalServerError
  const Response.internalServerError(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.internalServerError,
        _body = body;

  /// Request NoContent
  const Response.noContent(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.noContent,
        _body = body;

  /// Request NotAcceptable
  const Response.notAcceptable(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notAcceptable,
        _body = body;

  /// Request NotModified
  const Response.notModified(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notModified,
        _body = body;

  /// Request RequestEntityTooLarge
  const Response.requestEntityTooLarge(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestEntityTooLarge,
        _body = body;

  /// Request RequestTimeout
  const Response.requestTimeout(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestTimeout,
        _body = body;

  /// Request TooManyRequests
  const Response.tooManyRequests(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.tooManyRequests,
        _body = body;

  /// Request ServiceUnavailable
  const Response.serviceUnavailable(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.serviceUnavailable,
        _body = body;

  // ──────────────────────────────────────────────────────────────────
  // Deprecated constructors — use Response(statusCode: ..., body: ...)
  // ──────────────────────────────────────────────────────────────────

  @Deprecated('Use Response(statusCode: HttpStatus.alreadyReported, body: ...)')
  const Response.alreadyReported(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.alreadyReported,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.badGateway, body: ...)')
  const Response.badGateway(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.badGateway,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.conflict, body: ...)')
  const Response.conflict(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.conflict,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.connectionClosedWithoutResponse, body: ...)')
  const Response.connectionClosedWithoutResponse(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.connectionClosedWithoutResponse,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.continue_, body: ...)')
  const Response.continue_(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.continue_,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.expectationFailed, body: ...)')
  const Response.expectationFailed(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.expectationFailed,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.failedDependency, body: ...)')
  const Response.failedDependency(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.failedDependency,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.found, body: ...)')
  const Response.found({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.found,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.gatewayTimeout, body: ...)')
  const Response.gatewayTimeout(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.gatewayTimeout,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.gone, body: ...)')
  const Response.gone({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.gone,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.httpVersionNotSupported, body: ...)')
  const Response.httpVersionNotSupported(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.httpVersionNotSupported,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.imUsed, body: ...)')
  const Response.imUsed({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.imUsed,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.insufficientStorage, body: ...)')
  const Response.insufficientStorage(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.insufficientStorage,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.lengthRequired, body: ...)')
  const Response.lengthRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.lengthRequired,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.locked, body: ...)')
  const Response.locked({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.locked,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.loopDetected, body: ...)')
  const Response.loopDetected(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.loopDetected,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.misdirectedRequest, body: ...)')
  const Response.misdirectedRequest(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.misdirectedRequest,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.multiStatus, body: ...)')
  const Response.multiStatus(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.multiStatus,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.multipleChoices, body: ...)')
  const Response.multipleChoices(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.multipleChoices,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.networkAuthenticationRequired, body: ...)')
  const Response.networkAuthenticationRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.networkAuthenticationRequired,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.networkConnectTimeoutError, body: ...)')
  const Response.networkConnectTimeoutError(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.networkConnectTimeoutError,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.nonAuthoritativeInformation, body: ...)')
  const Response.nonAuthoritativeInformation(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.nonAuthoritativeInformation,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.notExtended, body: ...)')
  const Response.notExtended(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notExtended,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.notImplemented, body: ...)')
  const Response.notImplemented(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notImplemented,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.partialContent, body: ...)')
  const Response.partialContent(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.partialContent,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.paymentRequired, body: ...)')
  const Response.paymentRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.paymentRequired,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.permanentRedirect, body: ...)')
  const Response.permanentRedirect(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.permanentRedirect,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.preconditionFailed, body: ...)')
  const Response.preconditionFailed(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.preconditionFailed,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.processing, body: ...)')
  const Response.processing(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.processing,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.proxyAuthenticationRequired, body: ...)')
  const Response.proxyAuthenticationRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.proxyAuthenticationRequired,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.requestHeaderFieldsTooLarge, body: ...)')
  const Response.requestHeaderFieldsTooLarge(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestHeaderFieldsTooLarge,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.requestUriTooLong, body: ...)')
  const Response.requestUriTooLong(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestUriTooLong,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.requestedRangeNotSatisfiable, body: ...)')
  const Response.requestedRangeNotSatisfiable(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestedRangeNotSatisfiable,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.resetContent, body: ...)')
  const Response.resetContent(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.resetContent,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.seeOther, body: ...)')
  const Response.seeOther(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.seeOther,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.switchingProtocols, body: ...)')
  const Response.switchingProtocols(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.switchingProtocols,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.temporaryRedirect, body: ...)')
  const Response.temporaryRedirect(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.temporaryRedirect,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.unavailableForLegalReasons, body: ...)')
  const Response.unavailableForLegalReasons(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.unavailableForLegalReasons,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.unprocessableEntity, body: ...)')
  const Response.unprocessableEntity(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.unprocessableEntity,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.unsupportedMediaType, body: ...)')
  const Response.unsupportedMediaType(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.unsupportedMediaType,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.upgradeRequired, body: ...)')
  const Response.upgradeRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.upgradeRequired,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.useProxy, body: ...)')
  const Response.useProxy(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.useProxy,
        _body = body;

  @Deprecated('Use Response(statusCode: HttpStatus.variantAlsoNegotiates, body: ...)')
  const Response.variantAlsoNegotiates(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.variantAlsoNegotiates,
        _body = body;
}
