// @author viniciusddrft

import 'dart:convert';
import 'dart:io';

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

String? _csrfFromCookies(List<Cookie> cookies) {
  for (final c in cookies) {
    if (c.name == 'sparky_csrf') return c.value;
  }
  return null;
}

void main() {
  group('CsrfConfig', () {
    late SparkyTestClient client;

    tearDown(() async {
      await client.close();
    });

    test('POST without token is forbidden', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/action',
            middleware: (r) async => const Response.ok(body: {'ok': true}),
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );

      final res = await client.post('/action', body: {'a': 1});
      expect(res.statusCode, HttpStatus.forbidden);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['error'], 'csrf_validation_failed');
    });

    test('GET sets cookie; matching header + cookie allows POST', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (r) async => const Response.ok(body: 'hi'),
          ),
          RouteHttp.post(
            '/action',
            middleware: (r) async => const Response.ok(body: {'ok': true}),
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );

      final getRes = await client.get('/');
      expect(getRes.statusCode, 200);
      final token = _csrfFromCookies(getRes.cookies);
      expect(token, isNotNull);
      expect(token!.isNotEmpty, isTrue);

      final postRes = await client.post(
        '/action',
        body: {'a': 1},
        headers: {
          'Cookie': 'sparky_csrf=$token',
          'X-CSRF-Token': token,
        },
      );
      expect(postRes.statusCode, 200);
    });

    test('mismatched token is forbidden', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (r) async => const Response.ok(body: ''),
          ),
          RouteHttp.post(
            '/action',
            middleware: (r) async => const Response.ok(body: {}),
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );

      final getRes = await client.get('/');
      final token = _csrfFromCookies(getRes.cookies)!;

      final postRes = await client.post(
        '/action',
        body: {},
        headers: {
          'Cookie': 'sparky_csrf=$token',
          'X-CSRF-Token': '${token}x',
        },
      );
      expect(postRes.statusCode, HttpStatus.forbidden);
    });

    test('Bearer token skips CSRF when ignoreRequestsWithBearer', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/api',
            middleware: (r) async => const Response.ok(body: {'api': true}),
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );

      final res = await client.post(
        '/api',
        body: {},
        headers: {'Authorization': 'Bearer secret-token'},
      );
      expect(res.statusCode, 200);
    });

    test('form field _csrf matches cookie', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (r) async => const Response.ok(body: ''),
          ),
          RouteHttp.post(
            '/login',
            middleware: (r) async => const Response.ok(body: {'form': true}),
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );

      final token = _csrfFromCookies((await client.get('/')).cookies)!;
      final body = 'name=test&_csrf=${Uri.encodeQueryComponent(token)}';
      final postRes = await client.post(
        '/login',
        body: body,
        contentType: ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        ),
        headers: {
          'Cookie': 'sparky_csrf=$token',
        },
      );
      expect(postRes.statusCode, 200);
    });

    test('cookie is Secure by default', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (r) async => const Response.ok(body: ''),
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );

      final res = await client.get('/');
      final cookie =
          res.cookies.firstWhere((c) => c.name == 'sparky_csrf');
      expect(cookie.secure, isTrue);
    });

    test('JSON body _csrf matches cookie', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (r) async => const Response.ok(body: ''),
          ),
          RouteHttp.post(
            '/json',
            middleware: (r) async => const Response.ok(body: {}),
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );

      final token = _csrfFromCookies((await client.get('/')).cookies)!;
      final postRes = await client.post(
        '/json',
        body: {'_csrf': token, 'x': 1},
        headers: {
          'Cookie': 'sparky_csrf=$token',
        },
      );
      expect(postRes.statusCode, 200);
    });
  });
}
