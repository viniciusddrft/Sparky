// @author viniciusddrft

import 'dart:convert';
import 'dart:io';

import 'package:sparky/sparky.dart';
import 'package:test/test.dart';

void main() {
  group('Sparky.single config objects', () {
    test(
        'minimum non-trivial config fits in 6 params using ServerOptions + '
        'LimitsConfig + CacheConfig + CompressionConfig', () async {
      final server = Sparky.single(
        routes: [
          RouteHttp.get(
            '/hello',
            middleware: (_) async => const Response.ok(body: 'hi'),
          ),
        ],
        server: const ServerOptions(port: 0),
        limits: const LimitsConfig(requestTimeout: Duration(seconds: 5)),
        cache: const CacheConfig(
          ttl: Duration(minutes: 1),
          maxEntries: 128,
        ),
        compression: const CompressionConfig(enableGzip: true),
        logConfig: LogConfig.none,
      );
      await server.ready;
      addTearDown(server.close);

      final client = HttpClient();
      addTearDown(client.close);
      final req =
          await client.get('localhost', server.actualPort, '/hello');
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      expect(body, contains('hi'));
      expect(server.port, 0);
      expect(server.requestTimeout, const Duration(seconds: 5));
      expect(server.enableGzip, isTrue);
    });

    test('config objects values land on SparkyBase fields', () async {
      final server = Sparky.single(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (_) async => const Response.ok(body: 'ok'),
          ),
        ],
        server: const ServerOptions(port: 0, ip: 'localhost'),
        limits: const LimitsConfig(
          requestTimeout: Duration(seconds: 7),
          maxBodySize: 2048,
        ),
        compression: const CompressionConfig(
          enableGzip: true,
          gzipMinLength: 512,
        ),
        logConfig: LogConfig.none,
      );
      await server.ready;
      addTearDown(server.close);

      expect(server.port, 0);
      expect(server.ip, 'localhost');
      expect(server.requestTimeout, const Duration(seconds: 7));
      expect(server.maxBodySize, 2048);
      expect(server.enableGzip, isTrue);
      expect(server.gzipMinLength, 512);
    });

    test('default config objects match legacy defaults', () async {
      final server = Sparky.single(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (_) async => const Response.ok(body: 'ok'),
          ),
        ],
        server: const ServerOptions(port: 0),
        logConfig: LogConfig.none,
      );
      await server.ready;
      addTearDown(server.close);

      expect(server.ip, '0.0.0.0');
      expect(server.shared, isFalse);
      expect(server.requestTimeout, isNull);
      expect(server.maxBodySize, isNull);
      expect(server.enableGzip, isFalse);
      expect(server.gzipMinLength, 0);
    });
  });
}
