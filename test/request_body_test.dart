// @author viniciusddrft

import 'dart:convert';
import 'dart:io';

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  group('request.body unified API', () {
    late SparkyTestClient client;

    tearDown(() => client.close());

    test('body.text() returns the UTF-8 string', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/echo',
            middleware: (r) async => Response.ok(body: await r.body.text()),
          ),
        ],
      );

      final res = await client.post(
        '/echo',
        body: 'hello world',
        contentType: ContentType.text,
      );
      expect(res.statusCode, 200);
      expect(res.body, 'hello world');
    });

    test('body.bytes() returns the raw payload', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/len',
            middleware: (r) async {
              final b = await r.body.bytes();
              return Response.ok(body: {'len': b.length});
            },
          ),
        ],
      );

      final res = await client.post(
        '/len',
        body: List<int>.generate(16, (i) => i),
        contentType: ContentType.binary,
      );
      expect(res.statusCode, 200);
      expect((res.jsonBody as Map)['len'], 16);
    });

    test('body.json() parses JSON object bodies', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/user',
            middleware: (r) async {
              final m = await r.body.json();
              return Response.ok(body: {'name': m['name']});
            },
          ),
        ],
      );

      final res = await client.post('/user', body: {'name': 'sparky'});
      expect(res.statusCode, 200);
      expect((res.jsonBody as Map)['name'], 'sparky');
    });

    test('body.form() parses URL-encoded forms', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/login',
            middleware: (r) async {
              final f = await r.body.form();
              return Response.ok(body: {'user': f['user']});
            },
          ),
        ],
      );

      final res = await client.post(
        '/login',
        body: 'user=alice&pw=secret',
        contentType: ContentType('application', 'x-www-form-urlencoded'),
      );
      expect(res.statusCode, 200);
      expect((res.jsonBody as Map)['user'], 'alice');
    });

    test('body.multipart() parses multipart/form-data', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/upload',
            middleware: (r) async {
              final form = await r.body.multipart();
              return Response.ok(body: {
                'name': form.fields['name'],
                'hasFile': form.files.containsKey('avatar'),
              });
            },
          ),
        ],
      );

      const boundary = '----WebKitFormBoundary1234';
      final body = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="name"\r\n\r\n'
        'sparky\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="avatar"; filename="a.bin"\r\n'
        'Content-Type: application/octet-stream\r\n\r\n'
        'binarydata\r\n'
        '--$boundary--\r\n',
      );

      final res = await client.post(
        '/upload',
        body: body,
        contentType: ContentType('multipart', 'form-data',
            parameters: {'boundary': boundary}),
      );
      expect(res.statusCode, 200);
      final m = res.jsonBody as Map;
      expect(m['name'], 'sparky');
      expect(m['hasFile'], true);
    });

    test('body is cached: text() then json() does not re-consume the stream',
        () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/cached',
            middleware: (r) async {
              final raw = await r.body.text();
              final parsed = await r.body.json();
              return Response.ok(body: {
                'raw': raw,
                'name': parsed['name'],
              });
            },
          ),
        ],
      );

      final res = await client.post('/cached', body: {'name': 'x'});
      expect(res.statusCode, 200);
      final m = res.jsonBody as Map;
      expect(m['name'], 'x');
      expect(m['raw'], '{"name":"x"}');
    });

  });
}
