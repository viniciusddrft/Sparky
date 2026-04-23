// @author viniciusddrft

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  group('SparkyRequest', () {
    late SparkyTestClient client;

    tearDown(() => client.close());

    test('request.raw exposes the underlying HttpRequest', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/probe',
            middleware: (r) async {
              final raw = r.raw;
              // Sanity: `raw` is the underlying HttpRequest and surface-level
              // fields agree with the SparkyRequest wrapper.
              return Response.ok(body: {
                'sameMethod': raw.method == r.method,
                'samePath': raw.uri.path == r.uri.path,
                'method': raw.method,
                'path': raw.uri.path,
              });
            },
          ),
        ],
      );

      final res = await client.get('/probe');
      expect(res.statusCode, 200);
      final m = res.jsonBody as Map;
      expect(m['sameMethod'], true);
      expect(m['samePath'], true);
      expect(m['method'], 'GET');
      expect(m['path'], '/probe');
    });

    test('DI container is per-request (next request starts empty)', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/first',
            middleware: (r) async {
              r.provide<String>('set-once');
              return Response.ok(body: {'has': r.tryRead<String>()});
            },
          ),
          RouteHttp.get(
            '/second',
            middleware: (r) async =>
                Response.ok(body: {'has': r.tryRead<String>()}),
          ),
        ],
      );

      final a = await client.get('/first');
      final b = await client.get('/second');
      expect((a.jsonBody as Map)['has'], 'set-once');
      expect((b.jsonBody as Map)['has'], isNull);
    });

    test('requestId is assigned before handlers run and is unique per request',
        () async {
      // Dynamic route bypasses the response cache (which would otherwise
      // serve the first requestId for every hit).
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/id/:seq',
            middleware: (r) async => Response.ok(body: {'id': r.requestId}),
          ),
        ],
      );

      final ids = <String>{};
      final idPattern = RegExp(r'^[0-9a-f]{8}$');
      for (var i = 0; i < 5; i++) {
        final res = await client.get('/id/$i');
        final id = (res.jsonBody as Map)['id'] as String;
        expect(idPattern.hasMatch(id), isTrue, reason: 'id="$id" should be 8 hex chars');
        ids.add(id);
      }
      expect(ids.length, 5);
    });

    test('pathParams is populated for dynamic routes', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/users/:id',
            middleware: (r) async => Response.ok(body: r.pathParams),
          ),
        ],
      );

      final res = await client.get('/users/42');
      expect((res.jsonBody as Map)['id'], '42');
    });
  });
}
