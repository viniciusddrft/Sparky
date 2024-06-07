// Author: viniciusddrft

import 'dart:io';

///This class handles responses, with some constructors already configured with request code.
final class Response {
  /// Request Success
  const Response.ok({required this.body, this.contentType})
      : status = HttpStatus.ok;

  /// Request Not Found
  const Response.notFound({required this.body, this.contentType})
      : status = HttpStatus.notFound;

  /// Request Method Not Allowed
  const Response.methodNotAllowed({required this.body, this.contentType})
      : status = HttpStatus.methodNotAllowed;

  /// Request Bad Request
  const Response.badRequest({required this.body, this.contentType})
      : status = HttpStatus.badRequest;

  /// Request Accepted
  const Response.accepted({required this.body, this.contentType})
      : status = HttpStatus.accepted;

  /// Request Unauthorized
  const Response.unauthorized({required this.body, this.contentType})
      : status = HttpStatus.unauthorized;

  /// Request Forbidden
  const Response.forbidden({required this.body, this.contentType})
      : status = HttpStatus.forbidden;

  /// Request MovedTemporarily
  const Response.movedTemporarily({required this.body, this.contentType})
      : status = HttpStatus.movedTemporarily;

  /// Request MovedPermanently
  const Response.movedPermanently({required this.body, this.contentType})
      : status = HttpStatus.movedPermanently;

  /// Request AlreadyReported
  const Response.alreadyReported({required this.body, this.contentType})
      : status = HttpStatus.alreadyReported;

  /// Request BadGateway
  const Response.badGateway({required this.body, this.contentType})
      : status = HttpStatus.badGateway;

  /// Request Conflict
  const Response.conflict({required this.body, this.contentType})
      : status = HttpStatus.conflict;

  /// Request ConnectionClosedWithoutResponse
  const Response.connectionClosedWithoutResponse(
      {required this.body, this.contentType})
      : status = HttpStatus.connectionClosedWithoutResponse;

  /// Request Continue_
  const Response.continue_({required this.body, this.contentType})
      : status = HttpStatus.continue_;

  /// Request Created
  const Response.created({required this.body, this.contentType})
      : status = HttpStatus.created;

  /// Request ExpectationFailed
  const Response.expectationFailed({required this.body, this.contentType})
      : status = HttpStatus.expectationFailed;

  /// Request FailedDependency
  const Response.failedDependency({required this.body, this.contentType})
      : status = HttpStatus.failedDependency;

  /// Request Found
  const Response.found({required this.body, this.contentType})
      : status = HttpStatus.found;

  /// Request GatewayTimeout
  const Response.gatewayTimeout({required this.body, this.contentType})
      : status = HttpStatus.gatewayTimeout;

  /// Request Gone
  const Response.gone({required this.body, this.contentType})
      : status = HttpStatus.gone;

  /// Request HttpVersionNotSupported
  const Response.httpVersionNotSupported({required this.body, this.contentType})
      : status = HttpStatus.httpVersionNotSupported;

  /// Request ImUsed
  const Response.imUsed({required this.body, this.contentType})
      : status = HttpStatus.imUsed;

  /// Request InsufficientStorage
  const Response.insufficientStorage({required this.body, this.contentType})
      : status = HttpStatus.insufficientStorage;

  /// Request InternalServerError
  const Response.internalServerError({required this.body, this.contentType})
      : status = HttpStatus.internalServerError;

  /// Request LengthRequired
  const Response.lengthRequired({required this.body, this.contentType})
      : status = HttpStatus.lengthRequired;

  /// Request Locked
  const Response.locked({required this.body, this.contentType})
      : status = HttpStatus.locked;

  /// Request LoopDetected
  const Response.loopDetected({required this.body, this.contentType})
      : status = HttpStatus.loopDetected;

  /// Request MisdirectedRequest
  const Response.misdirectedRequest({required this.body, this.contentType})
      : status = HttpStatus.misdirectedRequest;

  /// Request MultiStatus
  const Response.multiStatus({required this.body, this.contentType})
      : status = HttpStatus.multiStatus;

  /// Request MultipleChoices
  const Response.multipleChoices({required this.body, this.contentType})
      : status = HttpStatus.multipleChoices;

  /// Request NetworkAuthenticationRequired
  const Response.networkAuthenticationRequired(
      {required this.body, this.contentType})
      : status = HttpStatus.networkAuthenticationRequired;

  /// Request NetworkConnectTimeoutError
  const Response.networkConnectTimeoutError(
      {required this.body, this.contentType})
      : status = HttpStatus.networkConnectTimeoutError;

  /// Request NoContent
  const Response.noContent({required this.body, this.contentType})
      : status = HttpStatus.noContent;

  /// Request NonAuthoritativeInformation
  const Response.nonAuthoritativeInformation(
      {required this.body, this.contentType})
      : status = HttpStatus.nonAuthoritativeInformation;

  /// Request NotAcceptable
  const Response.notAcceptable({required this.body, this.contentType})
      : status = HttpStatus.notAcceptable;

  /// Request NotExtended
  const Response.notExtended({required this.body, this.contentType})
      : status = HttpStatus.notExtended;

  /// Request NotImplemented
  const Response.notImplemented({required this.body, this.contentType})
      : status = HttpStatus.notImplemented;

  /// Request NotModified
  const Response.notModified({required this.body, this.contentType})
      : status = HttpStatus.notModified;

  /// Request PartialContent
  const Response.partialContent({required this.body, this.contentType})
      : status = HttpStatus.partialContent;

  /// Request PaymentRequired
  const Response.paymentRequired({required this.body, this.contentType})
      : status = HttpStatus.paymentRequired;

  /// Request PermanentRedirect
  const Response.permanentRedirect({required this.body, this.contentType})
      : status = HttpStatus.permanentRedirect;

  /// Request PreconditionFailed
  const Response.preconditionFailed({required this.body, this.contentType})
      : status = HttpStatus.preconditionFailed;

  /// Request Processing
  const Response.processing({required this.body, this.contentType})
      : status = HttpStatus.processing;

  /// Request ProxyAuthenticationRequired
  const Response.proxyAuthenticationRequired(
      {required this.body, this.contentType})
      : status = HttpStatus.proxyAuthenticationRequired;

  /// Request RequestEntityTooLarge
  const Response.requestEntityTooLarge({required this.body, this.contentType})
      : status = HttpStatus.requestEntityTooLarge;

  /// Request RequestHeaderFieldsTooLarge
  const Response.requestHeaderFieldsTooLarge(
      {required this.body, this.contentType})
      : status = HttpStatus.requestHeaderFieldsTooLarge;

  /// Request RequestTimeout
  const Response.requestTimeout({required this.body, this.contentType})
      : status = HttpStatus.requestTimeout;

  /// Request RequestUriTooLong
  const Response.requestUriTooLong({required this.body, this.contentType})
      : status = HttpStatus.requestUriTooLong;

  /// Request RequestedRangeNotSatisfiable
  const Response.requestedRangeNotSatisfiable(
      {required this.body, this.contentType})
      : status = HttpStatus.requestedRangeNotSatisfiable;

  /// Request ResetContent
  const Response.resetContent({required this.body, this.contentType})
      : status = HttpStatus.resetContent;

  /// Request SeeOther
  const Response.seeOther({required this.body, this.contentType})
      : status = HttpStatus.seeOther;

  /// Request ServiceUnavailable
  const Response.serviceUnavailable({required this.body, this.contentType})
      : status = HttpStatus.serviceUnavailable;

  /// Request SwitchingProtocols
  const Response.switchingProtocols({required this.body, this.contentType})
      : status = HttpStatus.switchingProtocols;

  /// Request TemporaryRedirect
  const Response.temporaryRedirect({required this.body, this.contentType})
      : status = HttpStatus.temporaryRedirect;

  /// Request TooManyRequests
  const Response.tooManyRequests({required this.body, this.contentType})
      : status = HttpStatus.tooManyRequests;

  /// Request UnavailableForLegalReasons
  const Response.unavailableForLegalReasons(
      {required this.body, this.contentType})
      : status = HttpStatus.unavailableForLegalReasons;

  /// Request UnprocessableEntity
  const Response.unprocessableEntity({required this.body, this.contentType})
      : status = HttpStatus.unprocessableEntity;

  /// Request UnsupportedMediaType
  const Response.unsupportedMediaType({required this.body, this.contentType})
      : status = HttpStatus.unsupportedMediaType;

  /// Request UpgradeRequired
  const Response.upgradeRequired({required this.body, this.contentType})
      : status = HttpStatus.upgradeRequired;

  /// Request UseProxy
  const Response.useProxy({required this.body, this.contentType})
      : status = HttpStatus.useProxy;

  /// Request VariantAlsoNegotiates
  const Response.variantAlsoNegotiates({required this.body, this.contentType})
      : status = HttpStatus.variantAlsoNegotiates;

  final int status;
  final String body;
  final ContentType? contentType;
}
