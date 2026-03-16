/// Author: viniciusddrft

part of '../sparky_server.dart';

/// A mixin that provides logging functionalities for the Sparky server.
///
/// This mixin allows the Sparky server to log information, errors, and request details
/// based on the configuration settings. It can log messages to the console, write logs to a file,
/// or both, depending on the `logConfig` and `logType` settings.
base mixin Logs on SparkyBase {
  IOSink? _file;

  bool get _shouldShow =>
      logConfig == LogConfig.showLogs ||
      logConfig == LogConfig.showAndWriteLogs;

  bool get _shouldWrite =>
      logConfig == LogConfig.writeLogs ||
      logConfig == LogConfig.showAndWriteLogs;

  /// Opens the server log and logs the server startup information.
  void _openServerLog() {
    if (logType == LogType.none) return;
    if (logType != LogType.all && logType != LogType.info) return;

    if (_shouldWrite) {
      _file = File(logFilePath).openWrite(mode: FileMode.append);
    }

    final message = '-- info --> Listen on $ip:$port';
    if (_shouldShow) print(message);
    if (_shouldWrite) _saveLogs(message);
  }

  /// Logs an error message.
  void _errorServerLog(Object e) {
    if (logType == LogType.none) return;
    if (logType != LogType.all && logType != LogType.errors) return;

    final message = '-- error --> Message $e';
    if (_shouldShow) print(message);
    if (_shouldWrite) _saveLogs(message);
  }

  /// Logs an HTTP request and its response.
  void _requestServerLog(HttpRequest request, Response routeResponse) {
    if (logType == LogType.none) return;
    if (logType != LogType.all && logType != LogType.info) return;

    final message =
        '-- info --> Method ${request.method} ${routeResponse.status} ${request.uri.path} from -> ${request.connectionInfo?.remoteAddress.host}';
    if (_shouldShow) print(message);
    if (_shouldWrite) _saveLogs(message);
  }

  /// Private function that saves log messages to a file.
  void _saveLogs(String message) =>
      _file?.write('${DateTime.now()}: $message\n');
}
