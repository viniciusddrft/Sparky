/// Author: viniciusddrft

part of '../sparky_server.dart';

/// A mixin that provides logging functionalities for the Sparky server.
///
/// This mixin allows the Sparky server to log information, errors, and request details
/// based on the configuration settings. It can log messages to the console, write logs to a file,
/// or both, depending on the `logConfig` and `logType` settings.
base mixin Logs on SparkyBase {
  IOSink? _file;

  /// Opens the server log and logs the server startup information.
  ///
  /// This function logs the server's listening address and port to the console
  /// and/or a file based on the current logging configuration.
  void _openServerLog() {
    if (logType == LogType.all || logType == LogType.info) {
      if (logConfig == LogConfig.showLogs ||
          logConfig == LogConfig.showAndWriteLogs) {
        print('-- info --> Listen on $ip:$port');
        if (logConfig == LogConfig.writeLogs ||
            logConfig == LogConfig.showAndWriteLogs) {
          _file = File('logs.txt').openWrite(mode: FileMode.append);
          _saveLogs('-- info --> Listen on $ip:$port');
        }
      }
    }
  }

  /// Logs an error message.
  ///
  /// This function logs the provided error message to the console and/or a file
  /// based on the current logging configuration.
  void _errorServerLog(Object e) {
    if (logType == LogType.all || logType == LogType.errors) {
      if (logConfig == LogConfig.showLogs ||
          logConfig == LogConfig.showAndWriteLogs) {
        print('-- error --> Message $e');
      }
      if (logConfig == LogConfig.writeLogs ||
          logConfig == LogConfig.showAndWriteLogs) {
        _saveLogs('-- error --> Message $e');
      }
    }
  }

  /// Logs an HTTP request and its response.
  ///
  /// This function logs the HTTP request method, response status, request URI path,
  /// and the client's remote address to the console and/or a file based on the current logging configuration.
  void _requestServerLog(HttpRequest request, Response routeResponse) {
    if (logType == LogType.all || logType == LogType.info) {
      if (logConfig == LogConfig.showLogs ||
          logConfig == LogConfig.showAndWriteLogs) {
        print(
            '-- info --> Method ${request.method} ${routeResponse.status} ${request.uri.path} from -> ${request.connectionInfo?.remoteAddress.host}');
      }
      if (logConfig == LogConfig.writeLogs ||
          logConfig == LogConfig.showAndWriteLogs) {
        _saveLogs(
            '-- info --> Method ${request.method} ${routeResponse.status} ${request.uri.path} from -> ${request.connectionInfo?.remoteAddress.host}:');
      }
    }
  }

  /// Private function that saves log messages to a file.
  ///
  /// This function writes the provided [message] to the log file with a timestamp.
  void _saveLogs(String message) =>
      _file?.write('${DateTime.now()}: $message\n');
}
