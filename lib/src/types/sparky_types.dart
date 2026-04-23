// @author viniciusddrft

import 'dart:io';
import 'package:sparky/src/request/sparky_request.dart';
import 'package:sparky/src/response/response.dart';

/// In this file, there are all types used in Sparky.

/// Normal middleware that receives a [SparkyRequest] and returns a [Future<Response>].
typedef Middleware = Future<Response> Function(SparkyRequest request);

/// Nullable middleware that receives a [SparkyRequest] and returns a [Future<Response?>].
typedef MiddlewareNullable = Future<Response?> Function(SparkyRequest request);

///WebSocket middleware that receives a [WebSocket] and returns void.
typedef MiddlewareWebSocket = Future<void> Function(WebSocket webSocket);

///Enum with log configuration.
enum LogConfig { showLogs, writeLogs, showAndWriteLogs, none }

///Enum with log types.
enum LogType { errors, info, all, none }

/// Output format for Sparky's built-in logger.
///
/// - [text]: human-readable single line (`-- info --> METHOD STATUS /path ...`).
/// - [json]: one JSON object per line (`{"level":"info","method":"GET",...}`).
///   Correlates with the request ID injected via `request.requestId` and echoed
///   in error response bodies.
enum LogFormat { text, json }

///Enum with web request methods.
enum AcceptedMethods {
  get('GET'),
  post('POST'),
  delete('DELETE'),
  put('PUT'),
  patch('PATCH'),
  head('HEAD'),
  options('OPTIONS'),
  trace('TRACE');

  const AcceptedMethods(this.text);
  final String text;
}
