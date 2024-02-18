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

  final int status;
  final String body;
  final ContentType? contentType;
}
