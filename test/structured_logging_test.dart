// @author viniciusddrft

import 'dart:convert';
import 'dart:io';

import 'package:sparky/sparky.dart' hide matches;
import 'package:test/test.dart';

Future<void> _hit(int port, String path) async {
  final client = HttpClient();
  try {
    final req = await client.open('GET', 'localhost', port, path);
    final res = await req.close();
    await res.drain<void>();
  } finally {
    client.close();
  }
}

File _tmpLog(String suffix) => File(
      '${Directory.systemTemp.path}/sparky_log_${suffix}_${DateTime.now().microsecondsSinceEpoch}.log',
    );

void main() {
  group('structured logging', () {
    test('JSON mode: each request gets a unique requestId in the log line',
        () async {
      final tmp = await _tmpLog('ids').create();
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete();
      });

      final server = Sparky.single(
        server: const ServerOptions(port: 0),
        logConfig: LogConfig.writeLogs,
        logFormat: LogFormat.json,
        logFilePath: tmp.path,
        routes: [
          RouteHttp.get('/ping',
              middleware: (r) async => Response.ok(body: r.requestId)),
        ],
      );
      await server.ready;
      await _hit(server.actualPort, '/ping');
      await _hit(server.actualPort, '/ping');
      await _hit(server.actualPort, '/ping');
      await server.close();

      final lines = (await tmp.readAsString())
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final events = lines
          .map((l) => json.decode(l) as Map<String, Object?>)
          .toList();

      final requestEvents =
          events.where((e) => e['method'] == 'GET').toList();
      expect(requestEvents.length, 3);

      final ids = requestEvents.map((e) => e['requestId'] as String).toList();
      expect(ids.toSet().length, 3, reason: 'request IDs must be unique: $ids');
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[0-9a-f]{8}$')));
      }

      for (final e in requestEvents) {
        expect(e['level'], 'info');
        expect(e['status'], 200);
        expect(e['path'], '/ping');
        expect(e['method'], 'GET');
        expect(e['durationMs'], isA<num>());
        expect(e.containsKey('bodySize'), isTrue);
        expect(e.containsKey('ts'), isTrue);
      }
    });

    test('requestId is accessible from handlers', () async {
      final tmp = await _tmpLog('handler').create();
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete();
      });

      final server = Sparky.single(
        server: const ServerOptions(port: 0),
        logConfig: LogConfig.none,
        routes: [
          RouteHttp.get('/id',
              middleware: (r) async => Response.ok(body: r.requestId)),
        ],
      );
      await server.ready;

      final client = HttpClient();
      final req =
          await client.open('GET', 'localhost', server.actualPort, '/id');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      await server.close();

      // Body comes through as either raw or JSON-quoted depending on
      // content type; strip optional quotes before matching.
      final id = body.replaceAll('"', '');
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(id), isTrue,
          reason: 'request id should be 8 hex chars, got: $id');
    });

    test('JSON mode: error body includes requestId', () async {
      final server = Sparky.single(
        server: const ServerOptions(port: 0),
        logConfig: LogConfig.none,
        logFormat: LogFormat.json,
        routes: [
          RouteHttp.get('/boom',
              middleware: (r) async => throw const NotFound(message: 'nope')),
        ],
      );
      await server.ready;

      final client = HttpClient();
      final req =
          await client.open('GET', 'localhost', server.actualPort, '/boom');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      await server.close();

      final decoded = jsonDecode(body) as Map<String, Object?>;
      expect(decoded['errorCode'], '404');
      expect(decoded['message'], 'nope');
      expect(decoded['requestId'], matches(RegExp(r'^[0-9a-f]{8}$')));
    });

    test('text mode: error body does not include requestId', () async {
      final server = Sparky.single(
        server: const ServerOptions(port: 0),
        logConfig: LogConfig.none,
        routes: [
          RouteHttp.get('/boom',
              middleware: (r) async => throw const NotFound(message: 'nope')),
        ],
      );
      await server.ready;

      final client = HttpClient();
      final req =
          await client.open('GET', 'localhost', server.actualPort, '/boom');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      await server.close();

      final decoded = jsonDecode(body) as Map<String, Object?>;
      expect(decoded.containsKey('requestId'), isFalse);
    });
  });
}
