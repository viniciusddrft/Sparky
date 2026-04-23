/// Author: viniciusddrft

part of '../sparky_server.dart';

/// A mixin that provides logging functionalities for the Sparky server.
///
/// Logs go to stdout, a file, or both based on [SparkyBase.logConfig] and are
/// filtered by [SparkyBase.logType]. Output format is controlled by
/// [SparkyBase.logFormat]: [LogFormat.text] (default, human-readable single
/// line) or [LogFormat.json] (one JSON object per line, with request ID).
base mixin Logs on SparkyBase {
  IOSink? _file;

  bool get _shouldShow =>
      logConfig == LogConfig.showLogs ||
      logConfig == LogConfig.showAndWriteLogs;

  bool get _shouldWrite =>
      logConfig == LogConfig.writeLogs ||
      logConfig == LogConfig.showAndWriteLogs;

  bool get _isJson => logFormat == LogFormat.json;

  /// Opens the server log and logs the server startup information.
  void _openServerLog() {
    if (logType == LogType.none) return;
    if (logType != LogType.all && logType != LogType.info) return;

    if (_shouldWrite) {
      _file = File(logFilePath).openWrite(mode: FileMode.append);
    }

    final protocol = securityContext != null ? 'https' : 'http';
    final message = _isJson
        ? json.encode({
            'ts': DateTime.now().toIso8601String(),
            'level': 'info',
            'event': 'listen',
            'protocol': protocol,
            'ip': ip,
            'port': port,
          })
        : '-- info --> Listen on $protocol://$ip:$port';
    if (_shouldShow) print(message);
    if (_shouldWrite) _saveLogs(message);
  }

  /// Logs an error message.
  void _errorServerLog(Object e) {
    if (logType == LogType.none) return;
    if (logType != LogType.all && logType != LogType.errors) return;

    final message = _isJson
        ? json.encode({
            'ts': DateTime.now().toIso8601String(),
            'level': 'error',
            'message': e.toString(),
          })
        : '-- error --> Message $e';
    if (_shouldShow) print(message);
    if (_shouldWrite) _saveLogs(message);
  }

  /// Logs an HTTP request and its response.
  void _requestServerLog(
    SparkyRequest request,
    Response routeResponse, {
    required Duration duration,
  }) {
    if (logType == LogType.none) return;
    if (logType != LogType.all && logType != LogType.info) return;

    final ip = request.connectionInfo?.remoteAddress.host;
    final bodySize = request.contentLength;
    final durationMs = duration.inMicroseconds / 1000.0;
    final message = _isJson
        ? json.encode({
            'ts': DateTime.now().toIso8601String(),
            'level': 'info',
            'requestId': request.requestId,
            'method': request.method,
            'status': routeResponse.status,
            'path': request.uri.path,
            'ip': ip,
            'durationMs': durationMs,
            'bodySize': bodySize,
          })
        : '-- info --> ${request.requestId} ${request.method} ${routeResponse.status} ${request.uri.path} ${durationMs.toStringAsFixed(1)}ms body=$bodySize from -> $ip';
    if (_shouldShow) print(message);
    if (_shouldWrite) _saveLogs(message);
  }

  /// Private function that saves log messages to a file.
  void _saveLogs(String message) => _isJson
      ? _file?.write('$message\n')
      : _file?.write('${DateTime.now()}: $message\n');
}
