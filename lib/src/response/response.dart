// @author viniciusddrft

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

  const Response.forbidden({required this.body, this.contentType})
      : status = HttpStatus.forbidden;

  const Response.movedTemporarily({required this.body, this.contentType})
      : status = HttpStatus.movedTemporarily;

  const Response.movedPermanently({required this.body, this.contentType})
      : status = HttpStatus.movedPermanently;

  const Response.alreadyReported({required this.body, this.contentType})
      : status = HttpStatus.alreadyReported;

  const Response.badGateway({required this.body, this.contentType})
      : status = HttpStatus.badGateway;

  const Response.conflict({required this.body, this.contentType})
      : status = HttpStatus.conflict;

  const Response.connectionClosedWithoutResponse(
      {required this.body, this.contentType})
      : status = HttpStatus.connectionClosedWithoutResponse;

  const Response.continue_({required this.body, this.contentType})
      : status = HttpStatus.continue_;

  const Response.created({required this.body, this.contentType})
      : status = HttpStatus.created;

  const Response.expectationFailed({required this.body, this.contentType})
      : status = HttpStatus.expectationFailed;

  const Response.failedDependency({required this.body, this.contentType})
      : status = HttpStatus.failedDependency;

  const Response.found({required this.body, this.contentType})
      : status = HttpStatus.found;

  const Response.gatewayTimeout({required this.body, this.contentType})
      : status = HttpStatus.gatewayTimeout;

  const Response.gone({required this.body, this.contentType})
      : status = HttpStatus.gone;

  const Response.httpVersionNotSupported({required this.body, this.contentType})
      : status = HttpStatus.httpVersionNotSupported;

  const Response.imUsed({required this.body, this.contentType})
      : status = HttpStatus.imUsed;

  const Response.insufficientStorage({required this.body, this.contentType})
      : status = HttpStatus.insufficientStorage;

  const Response.internalServerError({required this.body, this.contentType})
      : status = HttpStatus.internalServerError;

  const Response.lengthRequired({required this.body, this.contentType})
      : status = HttpStatus.lengthRequired;

  const Response.locked({required this.body, this.contentType})
      : status = HttpStatus.locked;

  const Response.loopDetected({required this.body, this.contentType})
      : status = HttpStatus.loopDetected;

  const Response.misdirectedRequest({required this.body, this.contentType})
      : status = HttpStatus.misdirectedRequest;

  const Response.multiStatus({required this.body, this.contentType})
      : status = HttpStatus.multiStatus;

  const Response.multipleChoices({required this.body, this.contentType})
      : status = HttpStatus.multipleChoices;

  const Response.networkAuthenticationRequired(
      {required this.body, this.contentType})
      : status = HttpStatus.networkAuthenticationRequired;

  const Response.networkConnectTimeoutError(
      {required this.body, this.contentType})
      : status = HttpStatus.networkConnectTimeoutError;

  const Response.noContent({required this.body, this.contentType})
      : status = HttpStatus.noContent;

  const Response.nonAuthoritativeInformation(
      {required this.body, this.contentType})
      : status = HttpStatus.nonAuthoritativeInformation;

  const Response.notAcceptable({required this.body, this.contentType})
      : status = HttpStatus.notAcceptable;

  const Response.notExtended({required this.body, this.contentType})
      : status = HttpStatus.notExtended;

  const Response.notImplemented({required this.body, this.contentType})
      : status = HttpStatus.notImplemented;

  const Response.notModified({required this.body, this.contentType})
      : status = HttpStatus.notModified;

  const Response.partialContent({required this.body, this.contentType})
      : status = HttpStatus.partialContent;

  const Response.paymentRequired({required this.body, this.contentType})
      : status = HttpStatus.paymentRequired;

  const Response.permanentRedirect({required this.body, this.contentType})
      : status = HttpStatus.permanentRedirect;

  const Response.preconditionFailed({required this.body, this.contentType})
      : status = HttpStatus.preconditionFailed;

  const Response.processing({required this.body, this.contentType})
      : status = HttpStatus.processing;

  const Response.proxyAuthenticationRequired(
      {required this.body, this.contentType})
      : status = HttpStatus.proxyAuthenticationRequired;

  const Response.requestEntityTooLarge({required this.body, this.contentType})
      : status = HttpStatus.requestEntityTooLarge;

  const Response.requestHeaderFieldsTooLarge(
      {required this.body, this.contentType})
      : status = HttpStatus.requestHeaderFieldsTooLarge;

  const Response.requestTimeout({required this.body, this.contentType})
      : status = HttpStatus.requestTimeout;

  const Response.requestUriTooLong({required this.body, this.contentType})
      : status = HttpStatus.requestUriTooLong;

  const Response.requestedRangeNotSatisfiable(
      {required this.body, this.contentType})
      : status = HttpStatus.requestedRangeNotSatisfiable;

  const Response.resetContent({required this.body, this.contentType})
      : status = HttpStatus.resetContent;

  const Response.seeOther({required this.body, this.contentType})
      : status = HttpStatus.seeOther;

  const Response.serviceUnavailable({required this.body, this.contentType})
      : status = HttpStatus.serviceUnavailable;

  const Response.switchingProtocols({required this.body, this.contentType})
      : status = HttpStatus.switchingProtocols;

  const Response.temporaryRedirect({required this.body, this.contentType})
      : status = HttpStatus.temporaryRedirect;

  const Response.tooManyRequests({required this.body, this.contentType})
      : status = HttpStatus.tooManyRequests;

  const Response.unavailableForLegalReasons(
      {required this.body, this.contentType})
      : status = HttpStatus.unavailableForLegalReasons;

  const Response.unprocessableEntity({required this.body, this.contentType})
      : status = HttpStatus.unprocessableEntity;

  const Response.unsupportedMediaType({required this.body, this.contentType})
      : status = HttpStatus.unsupportedMediaType;

  const Response.upgradeRequired({required this.body, this.contentType})
      : status = HttpStatus.upgradeRequired;

  const Response.useProxy({required this.body, this.contentType})
      : status = HttpStatus.useProxy;

  const Response.variantAlsoNegotiates({required this.body, this.contentType})
      : status = HttpStatus.variantAlsoNegotiates;

  final int status;
  final String body;
  final ContentType? contentType;
}
