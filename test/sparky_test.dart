// @author viniciusddrft

import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:sparky/sparky.dart';

void main() {
  group('Route validation', () {
    test('throws ErrorRouteEmpty when routes list is empty', () {
      expect(
        () => Sparky.server(
          routes: [],
          logConfig: LogConfig.none,
        ),
        throwsA(isA<ErrorRouteEmpty>()),
      );
    });

    test('throws RoutesRepeated when duplicate route names exist', () {
      expect(
        () => Sparky.server(
          routes: [
            RouteHttp.get('/test',
                middleware: (r) async => const Response.ok(body: 'a')),
            RouteHttp.get('/test',
                middleware: (r) async => const Response.ok(body: 'b')),
          ],
          logConfig: LogConfig.none,
        ),
        throwsA(isA<RoutesRepeated>()),
      );
    });
  });

  group('Response', () {
    test('ok has status 200', () {
      const resp = Response.ok(body: 'hello');
      expect(resp.status, HttpStatus.ok);
      expect(resp.body, 'hello');
    });

    test('notFound has status 404', () {
      const resp = Response.notFound(body: 'not found');
      expect(resp.status, HttpStatus.notFound);
    });

    test('methodNotAllowed has status 405', () {
      const resp = Response.methodNotAllowed(body: 'not allowed');
      expect(resp.status, HttpStatus.methodNotAllowed);
    });

    test('forbidden has status 403', () {
      const resp = Response.forbidden(body: 'forbidden');
      expect(resp.status, HttpStatus.forbidden);
    });

    test('internalServerError has status 500', () {
      const resp = Response.internalServerError(body: 'error');
      expect(resp.status, HttpStatus.internalServerError);
    });

    test('auto-serializes Map body to JSON', () {
      const resp = Response.ok(body: {'key': 'value'});
      expect(resp.body, '{"key":"value"}');
    });

    test('auto-serializes List body to JSON', () {
      const resp = Response.ok(body: [1, 2, 3]);
      expect(resp.body, '[1,2,3]');
    });

    test('keeps String body as-is', () {
      const resp = Response.ok(body: 'plain text');
      expect(resp.body, 'plain text');
    });

    test('custom status code via generic constructor', () {
      const resp = Response(statusCode: 418, body: 'teapot');
      expect(resp.status, 418);
      expect(resp.body, 'teapot');
    });

    test('headers are preserved', () {
      const resp = Response.ok(
        body: 'ok',
        headers: {'X-Custom': 'value'},
      );
      expect(resp.headers, {'X-Custom': 'value'});
    });
  });

  group('AuthJwt', () {
    const jwt = AuthJwt(secretKey: 'test-secret');

    test('generates a valid token with 3 parts', () {
      final token = jwt.generateToken({'user': 'admin'});
      expect(token.split('.').length, 3);
    });

    test('verifies a valid token', () {
      final token = jwt.generateToken({'user': 'admin'});
      expect(jwt.verifyToken(token), isTrue);
    });

    test('rejects token with wrong secret', () {
      final token = jwt.generateToken({'user': 'admin'});
      const otherJwt = AuthJwt(secretKey: 'wrong-secret');
      expect(otherJwt.verifyToken(token), isFalse);
    });

    test('rejects malformed token', () {
      expect(jwt.verifyToken('invalid'), isFalse);
      expect(jwt.verifyToken('a.b'), isFalse);
      expect(jwt.verifyToken('a.b.c'), isFalse);
    });

    test('decodes payload correctly', () {
      final token = jwt.generateToken({'user': 'admin', 'role': 'superuser'});
      final payload = jwt.decodePayload(token);
      expect(payload, isNotNull);
      expect(payload!['user'], 'admin');
      expect(payload['role'], 'superuser');
      expect(payload['iat'], isA<int>());
    });

    test('decodePayload returns null for malformed token', () {
      expect(jwt.decodePayload('invalid'), isNull);
      expect(jwt.decodePayload('a.b'), isNull);
    });

    test('token with expiration is valid before expiry', () {
      final token = jwt.generateToken(
        {'user': 'admin'},
        expiresIn: const Duration(hours: 1),
      );
      expect(jwt.verifyToken(token), isTrue);
      final payload = jwt.decodePayload(token);
      expect(payload!['exp'], isA<int>());
    });

    test('token with past expiration is rejected', () {
      final token = jwt.generateToken(
        {'user': 'admin'},
        expiresIn: const Duration(seconds: -1),
      );
      expect(jwt.verifyToken(token), isFalse);
    });
  });

  group('Route matching', () {
    test('static route matches exact path', () {
      final route = Route('/users');
      expect(route.matchPath('/users'), isNotNull);
      expect(route.matchPath('/users'), isEmpty);
      expect(route.matchPath('/other'), isNull);
    });

    test('dynamic route extracts single param', () {
      final route = Route('/users/:id');
      final params = route.matchPath('/users/42');
      expect(params, isNotNull);
      expect(params!['id'], '42');
    });

    test('dynamic route extracts multiple params', () {
      final route = Route('/users/:userId/posts/:postId');
      final params = route.matchPath('/users/7/posts/99');
      expect(params, isNotNull);
      expect(params!['userId'], '7');
      expect(params['postId'], '99');
    });

    test('dynamic route rejects non-matching path', () {
      final route = Route('/users/:id');
      expect(route.matchPath('/products/42'), isNull);
      expect(route.matchPath('/users'), isNull);
      expect(route.matchPath('/users/42/extra'), isNull);
    });

    test('isDynamic is true for parameterized routes', () {
      expect(Route('/users/:id').isDynamic, isTrue);
      expect(Route('/users').isDynamic, isFalse);
    });
  });

  group('Route cache versioning', () {
    test('versionCache starts at 0', () {
      final route = Route('/test');
      expect(route.versionCache, 0);
    });

    test('onUpdate increments versionCache', () {
      final route = Route('/test');
      route.onUpdate();
      expect(route.versionCache, 1);
      route.onUpdate();
      expect(route.versionCache, 2);
    });
  });

  group('RouteHttp', () {
    test('GET route only accepts GET', () {
      final route = RouteHttp.get('/test',
          middleware: (r) async => const Response.ok(body: ''));
      expect(route.acceptedMethods, contains(AcceptedMethods.get));
      expect(route.acceptedMethods!.length, 1);
    });

    test('POST route only accepts POST', () {
      final route = RouteHttp.post('/test',
          middleware: (r) async => const Response.ok(body: ''));
      expect(route.acceptedMethods, contains(AcceptedMethods.post));
      expect(route.acceptedMethods!.length, 1);
    });

    test('default RouteHttp accepts all methods', () {
      final route = RouteHttp('/test',
          middleware: (r) async => const Response.ok(body: ''));
      expect(route.acceptedMethods!.length, 8);
    });
  });

  group('RouteGroup', () {
    test('flatten prepends prefix to all routes', () {
      final group = RouteGroup('/api/v1', routes: [
        RouteHttp.get('/users',
            middleware: (r) async => const Response.ok(body: '')),
        RouteHttp.post('/products',
            middleware: (r) async => const Response.ok(body: '')),
      ]);

      final flattened = group.flatten();
      expect(flattened.length, 2);
      expect(flattened[0].name, '/api/v1/users');
      expect(flattened[1].name, '/api/v1/products');
    });
  });

  group('Pipeline', () {
    test('add and retrieve middlewares', () {
      final pipeline = Pipeline();
      pipeline.add((request) async => null);
      pipeline.add((request) async => const Response.ok(body: 'stop'));
      expect(pipeline.mids.length, 2);
    });
  });

  group('CorsConfig', () {
    test('default config has wildcard origin', () {
      const cors = CorsConfig();
      expect(cors.allowOrigins, contains('*'));
    });

    test('permissive config allows all methods', () {
      const cors = CorsConfig.permissive();
      expect(cors.allowMethods, contains('GET'));
      expect(cors.allowMethods, contains('POST'));
      expect(cors.allowMethods, contains('DELETE'));
      expect(cors.allowMethods, contains('OPTIONS'));
    });

    test('createMiddleware returns a function', () {
      const cors = CorsConfig();
      final middleware = cors.createMiddleware();
      expect(middleware, isA<Function>());
    });
  });

  group('HTTP integration', () {
    late Sparky server;
    late int port;

    setUp(() async {
      port = 9000 + DateTime.now().millisecondsSinceEpoch % 1000;
      server = Sparky.server(
        routes: [
          RouteHttp.get('/hello',
              middleware: (r) async => const Response.ok(body: '{"msg":"hi"}')),
          RouteHttp.post('/echo', middleware: (r) async {
            final body = await r.getJsonBody();
            return Response.ok(body: body);
          }),
          RouteHttp.get('/users/:id', middleware: (r) async {
            return Response.ok(body: '{"id":"${r.pathParams['id']}"}');
          }),
          RouteHttp.get('/items/:category/:itemId', middleware: (r) async {
            return Response.ok(
                body:
                    '{"category":"${r.pathParams['category']}","itemId":"${r.pathParams['itemId']}"}');
          }),
        ],
        port: port,
        logConfig: LogConfig.none,
      );
      await server.ready;
    });

    tearDown(() async {
      await server.close();
    });

    test('GET returns 200 with body', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/hello');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, 200);
      expect(body, '{"msg":"hi"}');
      client.close();
    });

    test('non-existent route returns 404', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/nonexistent');
      final response = await request.close();
      expect(response.statusCode, 404);
      client.close();
    });

    test('wrong method returns 405', () async {
      final client = HttpClient();
      final request = await client.post('localhost', port, '/hello');
      final response = await request.close();
      expect(response.statusCode, 405);
      client.close();
    });

    test('POST with JSON body echoes back', () async {
      final client = HttpClient();
      final request = await client.post('localhost', port, '/echo');
      request.headers.contentType = ContentType.json;
      request.write(json.encode({'name': 'sparky'}));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, 200);
      final decoded = json.decode(body);
      expect(decoded['name'], 'sparky');
      client.close();
    });

    test('dynamic route extracts path params', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/users/42');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, 200);
      final decoded = json.decode(body);
      expect(decoded['id'], '42');
      client.close();
    });

    test('dynamic route with multiple params', () async {
      final client = HttpClient();
      final request =
          await client.get('localhost', port, '/items/electronics/99');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, 200);
      final decoded = json.decode(body);
      expect(decoded['category'], 'electronics');
      expect(decoded['itemId'], '99');
      client.close();
    });
  });

  group('Graceful shutdown', () {
    test('server stops accepting connections after close', () async {
      final port = 9500 + DateTime.now().millisecondsSinceEpoch % 500;
      final server = Sparky.server(
        routes: [
          RouteHttp.get('/ping',
              middleware: (r) async => const Response.ok(body: 'pong')),
        ],
        port: port,
        logConfig: LogConfig.none,
      );
      await server.ready;

      final client = HttpClient();
      final request = await client.get('localhost', port, '/ping');
      final response = await request.close();
      expect(response.statusCode, 200);

      await server.close();

      expect(
        () async {
          final req = await client.get('localhost', port, '/ping');
          await req.close();
        },
        throwsA(anything),
      );
      client.close();
    });
  });
}
