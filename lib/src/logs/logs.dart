part of '../sparky_server.dart';

base mixin Logs on SparkyBase {
  IOSink? _file;

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

  /// Private function that saves logs.
  void _saveLogs(String message) =>
      _file?.write('${DateTime.now()}: $message\n');
}
