// @author viniciusddrft

import 'dart:io';
import 'package:sparky/src/response/response.dart';

/// In this file, there are all types used in Sparky.

/// Normal middleware that receives an [HttpRequest] and returns a [Future<Response>].
typedef Middleware = Future<Response> Function(HttpRequest request);

/// Nullable middleware that receives an [HttpRequest] and returns a [Future<Response?>].
typedef MiddlewareNulable = Future<Response?> Function(HttpRequest request);

///WebSocket middleware that receives a [WebSocket] and returns void.
typedef MiddlewareWebSocket = Future<void> Function(WebSocket webSocket);

///Enum with log configuration.
enum LogConfig { showLogs, writeLogs, showAndWriteLogs, none }

///Enum with log types.
enum LogType { errors, info, all, none }

///Enum with web request methods.
enum AcceptedMethods {
  get('GET'),
  post('POST'),
  delete('DELETE'),
  put('PUT');

  const AcceptedMethods(this.text);
  final String text;
}
