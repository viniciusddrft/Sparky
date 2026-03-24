// Author: viniciusddrft

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// Request AlreadyReported
  const Response.alreadyReported(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.alreadyReported,
        _body = body;

  /// Request BadGateway
  const Response.badGateway(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.badGateway,
        _body = body;

  /// Request Conflict
  const Response.conflict(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.conflict,
        _body = body;

  /// Request ConnectionClosedWithoutResponse
  const Response.connectionClosedWithoutResponse(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.connectionClosedWithoutResponse,
        _body = body;

  /// Request Continue_
  const Response.continue_(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.continue_,
        _body = body;

  /// Request Created
  const Response.created({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.created,
        _body = body;

  /// Request ExpectationFailed
  const Response.expectationFailed(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.expectationFailed,
        _body = body;

  /// Request FailedDependency
  const Response.failedDependency(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.failedDependency,
        _body = body;

  /// Request Found
  const Response.found({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.found,
        _body = body;

  /// Request GatewayTimeout
  const Response.gatewayTimeout(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.gatewayTimeout,
        _body = body;

  /// Request Gone
  const Response.gone({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.gone,
        _body = body;

  /// Request HttpVersionNotSupported
  const Response.httpVersionNotSupported(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.httpVersionNotSupported,
        _body = body;

  /// Request ImUsed
  const Response.imUsed({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.imUsed,
        _body = body;

  /// Request InsufficientStorage
  const Response.insufficientStorage(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.insufficientStorage,
        _body = body;

  /// Request InternalServerError
  const Response.internalServerError(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.internalServerError,
        _body = body;

  /// Request LengthRequired
  const Response.lengthRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.lengthRequired,
        _body = body;

  /// Request Locked
  const Response.locked({required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.locked,
        _body = body;

  /// Request LoopDetected
  const Response.loopDetected(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.loopDetected,
        _body = body;

  /// Request MisdirectedRequest
  const Response.misdirectedRequest(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.misdirectedRequest,
        _body = body;

  /// Request MultiStatus
  const Response.multiStatus(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.multiStatus,
        _body = body;

  /// Request MultipleChoices
  const Response.multipleChoices(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.multipleChoices,
        _body = body;

  /// Request NetworkAuthenticationRequired
  const Response.networkAuthenticationRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.networkAuthenticationRequired,
        _body = body;

  /// Request NetworkConnectTimeoutError
  const Response.networkConnectTimeoutError(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.networkConnectTimeoutError,
        _body = body;

  /// Request NoContent
  const Response.noContent(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.noContent,
        _body = body;

  /// Request NonAuthoritativeInformation
  const Response.nonAuthoritativeInformation(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.nonAuthoritativeInformation,
        _body = body;

  /// Request NotAcceptable
  const Response.notAcceptable(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notAcceptable,
        _body = body;

  /// Request NotExtended
  const Response.notExtended(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notExtended,
        _body = body;

  /// Request NotImplemented
  const Response.notImplemented(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notImplemented,
        _body = body;

  /// Request NotModified
  const Response.notModified(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.notModified,
        _body = body;

  /// Request PartialContent
  const Response.partialContent(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.partialContent,
        _body = body;

  /// Request PaymentRequired
  const Response.paymentRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.paymentRequired,
        _body = body;

  /// Request PermanentRedirect
  const Response.permanentRedirect(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.permanentRedirect,
        _body = body;

  /// Request PreconditionFailed
  const Response.preconditionFailed(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.preconditionFailed,
        _body = body;

  /// Request Processing
  const Response.processing(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.processing,
        _body = body;

  /// Request ProxyAuthenticationRequired
  const Response.proxyAuthenticationRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.proxyAuthenticationRequired,
        _body = body;

  /// Request RequestEntityTooLarge
  const Response.requestEntityTooLarge(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestEntityTooLarge,
        _body = body;

  /// Request RequestHeaderFieldsTooLarge
  const Response.requestHeaderFieldsTooLarge(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestHeaderFieldsTooLarge,
        _body = body;

  /// Request RequestTimeout
  const Response.requestTimeout(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestTimeout,
        _body = body;

  /// Request RequestUriTooLong
  const Response.requestUriTooLong(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestUriTooLong,
        _body = body;

  /// Request RequestedRangeNotSatisfiable
  const Response.requestedRangeNotSatisfiable(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.requestedRangeNotSatisfiable,
        _body = body;

  /// Request ResetContent
  const Response.resetContent(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.resetContent,
        _body = body;

  /// Request SeeOther
  const Response.seeOther(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.seeOther,
        _body = body;

  /// Request ServiceUnavailable
  const Response.serviceUnavailable(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.serviceUnavailable,
        _body = body;

  /// Request SwitchingProtocols
  const Response.switchingProtocols(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.switchingProtocols,
        _body = body;

  /// Request TemporaryRedirect
  const Response.temporaryRedirect(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.temporaryRedirect,
        _body = body;

  /// Request TooManyRequests
  const Response.tooManyRequests(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.tooManyRequests,
        _body = body;

  /// Request UnavailableForLegalReasons
  const Response.unavailableForLegalReasons(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.unavailableForLegalReasons,
        _body = body;

  /// Request UnprocessableEntity
  const Response.unprocessableEntity(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.unprocessableEntity,
        _body = body;

  /// Request UnsupportedMediaType
  const Response.unsupportedMediaType(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.unsupportedMediaType,
        _body = body;

  /// Request UpgradeRequired
  const Response.upgradeRequired(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.upgradeRequired,
        _body = body;

  /// Request UseProxy
  const Response.useProxy(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.useProxy,
        _body = body;

  /// Request VariantAlsoNegotiates
  const Response.variantAlsoNegotiates(
      {required Object body, this.contentType, this.headers, this.cookies})
      : status = HttpStatus.variantAlsoNegotiates,
        _body = body;
}
