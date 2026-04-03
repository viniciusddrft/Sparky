// @author viniciusddrft

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:test/test.dart' hide isList, isMap, matches;
import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';

/// Top-level factory that throws on isolate index 1 (for error rollback tests).
Sparky _failingOnSecondIsolate(int isolateIndex) {
  if (isolateIndex == 1) {
    throw StateError('Simulated factory failure on isolate 1');
  }
  return Sparky.single(
    port: 4598,
    shared: true,
    logConfig: LogConfig.none,
    routes: [
      RouteHttp.get('/test',
          middleware: (r) async => const Response.ok(body: 'ok')),
    ],
  );
}

/// Top-level factory for isolate tests (closures can't cross isolate boundaries).
Sparky _createTestServer(int isolateIndex) {
  return Sparky.single(
    port: 4599,
    shared: true,
    logConfig: LogConfig.none,
    routes: [
      RouteHttp.get('/hello', middleware: (r) async {
        return Response.ok(body: {
          'message': 'Hello from isolate',
          'isolate': Isolate.current.debugName,
        });
      }),
    ],
  );
}

void main() {
  group('Route validation', () {
    test('throws ErrorRouteEmpty when routes list is empty', () {
      expect(
        () => Sparky.single(
          routes: [],
          logConfig: LogConfig.none,
        ),
        throwsA(isA<ErrorRouteEmpty>()),
      );
    });

    test('throws RoutesRepeated when duplicate route names exist', () {
      expect(
        () => Sparky.single(
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

    test('token has no base64url padding characters (RFC 7519)', () {
      final token = jwt.generateToken({'user': 'admin'});
      expect(token.contains('='), isFalse);
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
      server = Sparky.single(
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
        port: 0,
        logConfig: LogConfig.none,
      );
      await server.ready;
      port = server.actualPort;
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

  group('Validator', () {
    test('validate returns empty map when all fields are valid', () {
      final schema = Validator({
        'name': [isRequired, isString, minLength(2)],
        'age': [isRequired, isNum, min(0)],
      });
      final errors = schema.validate({'name': 'Alice', 'age': 25});
      expect(errors, isEmpty);
    });

    test('isRequired catches missing fields', () {
      const schema = Validator({
        'name': [isRequired],
      });
      final errors = schema.validate({});
      expect(errors['name'], 'name is required');
    });

    test('isString rejects non-string values', () {
      const schema = Validator({
        'name': [isRequired, isString],
      });
      final errors = schema.validate({'name': 123});
      expect(errors['name'], 'name must be a string');
    });

    test('isNum rejects non-numeric values', () {
      const schema = Validator({
        'age': [isRequired, isNum],
      });
      final errors = schema.validate({'age': 'old'});
      expect(errors['age'], 'age must be a number');
    });

    test('isInt rejects non-integer values', () {
      const schema = Validator({
        'count': [isRequired, isInt],
      });
      final errors = schema.validate({'count': 3.14});
      expect(errors['count'], 'count must be an integer');
    });

    test('isBool rejects non-boolean values', () {
      const schema = Validator({
        'active': [isRequired, isBool],
      });
      final errors = schema.validate({'active': 'yes'});
      expect(errors['active'], 'active must be a boolean');
    });

    test('isList rejects non-list values', () {
      const schema = Validator({
        'tags': [isRequired, isList],
      });
      final errors = schema.validate({'tags': 'not-a-list'});
      expect(errors['tags'], 'tags must be a list');
    });

    test('isMap rejects non-map values', () {
      const schema = Validator({
        'meta': [isRequired, isMap],
      });
      final errors = schema.validate({'meta': 'not-a-map'});
      expect(errors['meta'], 'meta must be a map');
    });

    test('minLength rejects short strings', () {
      final schema = Validator({
        'name': [isRequired, isString, minLength(3)],
      });
      final errors = schema.validate({'name': 'ab'});
      expect(errors['name'], 'name must be at least 3 characters');
    });

    test('maxLength rejects long strings', () {
      final schema = Validator({
        'code': [isRequired, isString, maxLength(5)],
      });
      final errors = schema.validate({'code': 'toolong'});
      expect(errors['code'], 'code must be at most 5 characters');
    });

    test('min rejects values below minimum', () {
      final schema = Validator({
        'age': [isRequired, isNum, min(18)],
      });
      final errors = schema.validate({'age': 10});
      expect(errors['age'], 'age must be at least 18');
    });

    test('max rejects values above maximum', () {
      final schema = Validator({
        'score': [isRequired, isNum, max(100)],
      });
      final errors = schema.validate({'score': 150});
      expect(errors['score'], 'score must be at most 100');
    });

    test('isEmail validates email format', () {
      const schema = Validator({
        'email': [isRequired, isString, isEmail],
      });
      expect(schema.validate({'email': 'user@example.com'}), isEmpty);
      expect(schema.validate({'email': 'invalid'})['email'],
          'email must be a valid email');
    });

    test('matches validates against regex', () {
      final schema = Validator({
        'zip': [isRequired, isString, matches(RegExp(r'^\d{5}$'))],
      });
      expect(schema.validate({'zip': '12345'}), isEmpty);
      expect(schema.validate({'zip': 'abcde'})['zip'],
          'zip has an invalid format');
    });

    test('oneOf rejects values not in allowed list', () {
      final schema = Validator({
        'role': [
          isRequired,
          oneOf(['admin', 'user', 'guest'])
        ],
      });
      expect(schema.validate({'role': 'admin'}), isEmpty);
      expect(schema.validate({'role': 'hacker'})['role'],
          'role must be one of: admin, user, guest');
    });

    test('minItems and maxItems validate list length', () {
      final schema = Validator({
        'tags': [isRequired, isList, minItems(1), maxItems(3)],
      });
      expect(schema.validate({'tags': []}), isNotEmpty);
      expect(
          schema.validate({
            'tags': ['a']
          }),
          isEmpty);
      expect(
          schema.validate({
            'tags': ['a', 'b', 'c', 'd']
          }),
          isNotEmpty);
    });

    test('custom rule works with predicate', () {
      final schema = Validator({
        'even': [
          isRequired,
          isInt,
          custom((v) => v is int && v % 2 == 0, 'must be even'),
        ],
      });
      expect(schema.validate({'even': 4}), isEmpty);
      expect(schema.validate({'even': 3})['even'], 'must be even');
    });

    test('stops at first error per field', () {
      final schema = Validator({
        'name': [isRequired, isString, minLength(3)],
      });
      // null triggers isRequired, should not continue to isString/minLength
      final errors = schema.validate({});
      expect(errors['name'], 'name is required');
    });

    test('type rules skip null values (only isRequired catches null)', () {
      final schema = Validator({
        'name': [isString, minLength(3)],
      });
      // name is absent (null) but not required — should pass
      final errors = schema.validate({});
      expect(errors, isEmpty);
    });

    test('validates multiple fields independently', () {
      const schema = Validator({
        'name': [isRequired, isString],
        'age': [isRequired, isNum],
        'email': [isRequired, isString, isEmail],
      });
      final errors = schema.validate({});
      expect(errors.length, 3);
      expect(errors.containsKey('name'), isTrue);
      expect(errors.containsKey('age'), isTrue);
      expect(errors.containsKey('email'), isTrue);
    });
  });

  group('Gzip compression', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/data',
              middleware: (r) async =>
                  const Response.ok(body: '{"msg":"hello world"}')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        enableGzip: true,
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('returns gzip-encoded body when client accepts gzip', () async {
      final client = HttpClient()..autoUncompress = false;
      final request = await client.get('localhost', port, '/data');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
      final bytes = await response
          .fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      final decompressed = utf8.decode(gzip.decode(bytes));
      expect(decompressed, '{"msg":"hello world"}');
      client.close();
    });

    test('returns plain body when client does not accept gzip', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/data');
      // explicitly remove accept-encoding
      request.headers.removeAll(HttpHeaders.acceptEncodingHeader);
      final response = await request.close();
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), isNull);
      final body = await utf8.decoder.bind(response).join();
      expect(body, '{"msg":"hello world"}');
      client.close();
    });
  });

  group('Gzip with minLength', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/small',
              middleware: (r) async => const Response.ok(body: '{"ok":true}')),
          RouteHttp.get('/big', middleware: (r) async {
            final largeBody = '{"data":"${'x' * 2000}"}';
            return Response.ok(body: largeBody);
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
        enableGzip: true,
        gzipMinLength: 1024,
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('skips gzip when body is smaller than gzipMinLength', () async {
      final client = HttpClient()..autoUncompress = false;
      final request = await client.get('localhost', port, '/small');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), isNull);
      final body = await utf8.decoder.bind(response).join();
      expect(body, '{"ok":true}');
      client.close();
    });

    test('applies gzip when body is larger than gzipMinLength', () async {
      final client = HttpClient()..autoUncompress = false;
      final request = await client.get('localhost', port, '/big');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
      final bytes = await response
          .fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      final decompressed = utf8.decode(gzip.decode(bytes));
      expect(decompressed, contains('xxxx'));
      client.close();
    });
  });

  group('Content negotiation', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/negotiation', middleware: (r) async {
            final type = r.preferredType(
              const ['application/json', 'text/html', 'text/plain'],
            );
            if (type == null) {
              return const Response.notAcceptable(
                body: '{"errorCode":"406","message":"Not Acceptable"}',
              );
            }
            if (type == 'text/html') {
              return Response.ok(
                body: '<h1>Hello</h1>',
                contentType: ContentType.html,
              );
            }
            if (type == 'text/plain') {
              return Response.ok(
                body: 'hello',
                contentType: ContentType.text,
              );
            }
            return Response.ok(
              body: '{"message":"hello"}',
              contentType: ContentType.json,
            );
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('selects JSON when Accept is application/json', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/negotiation');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'application/json');
      expect(body, '{"message":"hello"}');
      client.close();
    });

    test('selects HTML when Accept is text/html', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/negotiation');
      request.headers.set(HttpHeaders.acceptHeader, 'text/html');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'text/html');
      expect(body, '<h1>Hello</h1>');
      client.close();
    });

    test('returns 406 when no content type matches Accept', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/negotiation');
      request.headers.set(HttpHeaders.acceptHeader, 'image/png');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.notAcceptable);
      client.close();
    });
  });

  group('Static files', () {
    late Sparky server;
    late int port;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sparky-static-test-');
      await File('${tempDir.path}/index.html').writeAsString('<h1>home</h1>');
      await File('${tempDir.path}/app.js').writeAsString('console.log("ok");');
      await File('${tempDir.path}/logo.png').writeAsBytes([0, 1, 2, 3, 4]);

      server = Sparky.single(
        routes: [
          RouteHttp.get('/api/ping',
              middleware: (r) async => const Response.ok(body: 'pong')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        pipelineBefore: Pipeline()
          ..add(
            StaticFiles(
              urlPath: '/public',
              directory: tempDir.path,
            ).createMiddleware(),
          ),
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('serves text static file with correct content-type', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/public/app.js');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'application/javascript');
      expect(body, 'console.log("ok");');
      client.close();
    });

    test('serves binary static file without corrupting bytes', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/public/logo.png');
      final response = await request.close();
      final bodyBytes = await response.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'image/png');
      expect(bodyBytes, [0, 1, 2, 3, 4]);
      client.close();
    });

    test('serves index.html when requesting base static path', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/public');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'text/html');
      expect(body, '<h1>home</h1>');
      client.close();
    });

    test('HEAD request returns headers with empty body', () async {
      final client = HttpClient();
      final request =
          await client.open('HEAD', 'localhost', port, '/public/app.js');
      final response = await request.close();
      final body = await response.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'application/javascript');
      expect(body, isEmpty);
      client.close();
    });

    test('prevents path traversal attempts', () async {
      final socket = await Socket.connect('localhost', port);
      socket.write(
        'GET /public/%2E%2E/secrets.txt HTTP/1.1\r\n'
        'Host: localhost:$port\r\n'
        'Connection: close\r\n'
        '\r\n',
      );
      await socket.flush();
      final rawResponse = await utf8.decoder.bind(socket).join();
      final statusLine = rawResponse.split('\r\n').first;
      final statusCode = int.tryParse(statusLine.split(' ')[1]);
      expect(
        statusCode == HttpStatus.forbidden || statusCode == HttpStatus.notFound,
        isTrue,
      );
      await socket.close();
    });

    test('falls through when static file does not exist', () async {
      final client = HttpClient();
      final request =
          await client.get('localhost', port, '/public/missing.txt');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.notFound);
      client.close();
    });

    test('does not serve static files for POST', () async {
      final client = HttpClient();
      final request = await client.post('localhost', port, '/public/app.js');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.notFound);
      client.close();
    });

    test('returns ETag, Last-Modified and Cache-Control headers', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/public/app.js');
      final response = await request.close();
      await utf8.decoder.bind(response).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value(HttpHeaders.etagHeader), isNotNull);
      expect(response.headers.value(HttpHeaders.lastModifiedHeader), isNotNull);
      expect(response.headers.value(HttpHeaders.cacheControlHeader),
          'public, max-age=3600');
      client.close();
    });

    test('returns 304 Not Modified when If-None-Match matches ETag', () async {
      final client = HttpClient();
      final firstRequest =
          await client.get('localhost', port, '/public/app.js');
      final firstResponse = await firstRequest.close();
      await utf8.decoder.bind(firstResponse).join();
      final etag = firstResponse.headers.value(HttpHeaders.etagHeader)!;

      final secondRequest =
          await client.get('localhost', port, '/public/app.js');
      secondRequest.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      final secondResponse = await secondRequest.close();
      expect(secondResponse.statusCode, HttpStatus.notModified);
      client.close();
    });
  });

  group('Body size limits', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.post('/echo', middleware: (r) async {
            final body = await r.getRawBody();
            return Response.ok(body: {'size': body.length});
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
        maxBodySize: 10,
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('rejects request above maxBodySize with content-length', () async {
      final client = HttpClient();
      final request = await client.post('localhost', port, '/echo');
      request.write('12345678901');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
      client.close();
    });

    test('accepts request exactly at maxBodySize', () async {
      final client = HttpClient();
      final request = await client.post('localhost', port, '/echo');
      request.write('1234567890');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      client.close();
    });

    test('rejects chunked request above maxBodySize', () async {
      final client = HttpClient();
      final request = await client.post('localhost', port, '/echo');
      request.headers.chunkedTransferEncoding = true;
      request.write('12345');
      request.write('67890');
      request.write('1');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
      client.close();
    });
  });

  group('Cache manager behavior', () {
    late Sparky server;
    late int port;

    tearDown(() async {
      await server.close();
    });

    test('respects cacheTtl for static routes', () async {
      var hits = 0;
      server = Sparky.single(
        routes: [
          RouteHttp.get('/cached', middleware: (r) async {
            hits++;
            return Response.ok(body: {'hits': hits});
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
        cacheTtl: const Duration(milliseconds: 80),
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      final req1 = await client.get('localhost', port, '/cached');
      await req1.close();
      final req2 = await client.get('localhost', port, '/cached');
      await req2.close();
      expect(hits, 1);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final req3 = await client.get('localhost', port, '/cached');
      await req3.close();
      expect(hits, 2);
      client.close();
    });

    test('evicts least recently used entry when maxEntries is reached',
        () async {
      var oneHits = 0;
      var twoHits = 0;
      server = Sparky.single(
        routes: [
          RouteHttp.get('/one', middleware: (r) async {
            oneHits++;
            return Response.ok(body: {'hits': oneHits});
          }),
          RouteHttp.get('/two', middleware: (r) async {
            twoHits++;
            return Response.ok(body: {'hits': twoHits});
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
        cacheMaxEntries: 1,
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      var req = await client.get('localhost', port, '/one');
      await req.close();
      req = await client.get('localhost', port, '/one');
      await req.close();
      expect(oneHits, 1);

      req = await client.get('localhost', port, '/two');
      await req.close();
      req = await client.get('localhost', port, '/one');
      await req.close();
      expect(oneHits, 2);
      client.close();
    });

    test('does not cache non-idempotent methods like POST', () async {
      var hits = 0;
      server = Sparky.single(
        routes: [
          RouteHttp.post('/submit', middleware: (r) async {
            hits++;
            return Response.ok(body: {'hits': hits});
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
        cacheTtl: const Duration(seconds: 10),
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      var req = await client.post('localhost', port, '/submit');
      await req.close();
      req = await client.post('localhost', port, '/submit');
      await req.close();
      expect(hits, 2);
      client.close();
    });
  });

  group('Cookies', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/set-cookie', middleware: (r) async {
            final cookie = Cookie('session', 'abc123')
              ..httpOnly = true
              ..secure = true;
            return Response.ok(
              body: {'ok': true},
              cookies: [cookie],
            );
          }),
          RouteHttp.get('/read-cookie', middleware: (r) async {
            final value = r.getCookie('session')?.value;
            return Response.ok(body: {'session': value ?? 'none'});
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('sets cookie in response', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/set-cookie');
      final response = await request.close();
      final cookie = response.cookies.firstWhere((c) => c.name == 'session');
      expect(cookie.value, 'abc123');
      expect(cookie.httpOnly, isTrue);
      client.close();
    });

    test('reads cookie from request', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/read-cookie');
      request.headers.add(HttpHeaders.cookieHeader, 'session=user-token');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      expect(json.decode(body)['session'], 'user-token');
      client.close();
    });
  });

  group('Rate limiter', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/limited',
              middleware: (r) async => const Response.ok(body: {'ok': true})),
        ],
        port: 0,
        logConfig: LogConfig.none,
        pipelineBefore: Pipeline()
          ..add(
            RateLimiter(
              maxRequests: 2,
              window: const Duration(milliseconds: 200),
            ).createMiddleware(),
          ),
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('returns 429 and retry-after when over limit', () async {
      final client = HttpClient();
      for (var i = 0; i < 2; i++) {
        final request = await client.get('localhost', port, '/limited');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
      }
      final blockedRequest = await client.get('localhost', port, '/limited');
      final blockedResponse = await blockedRequest.close();
      expect(blockedResponse.statusCode, HttpStatus.tooManyRequests);
      final retryAfter =
          int.parse(blockedResponse.headers.value('Retry-After') ?? '0');
      expect(retryAfter, greaterThanOrEqualTo(1));
      client.close();
    });
  });

  group('Content negotiation helpers', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/best', middleware: (r) async {
            final preferred = r.preferredType(
              const ['application/json', 'text/html', 'text/plain'],
            );
            return Response.ok(body: {'preferred': preferred ?? 'none'});
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('defaults to first available when accept is missing', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/best');
      final response = await request.close();
      final body = json.decode(await utf8.decoder.bind(response).join());
      expect(body['preferred'], 'application/json');
      client.close();
    });

    test('supports wildcard and q-values', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/best');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/*;q=0.5, application/json;q=0.9',
      );
      final response = await request.close();
      final body = json.decode(await utf8.decoder.bind(response).join());
      expect(body['preferred'], 'application/json');
      client.close();
    });

    test('respects q-values when */* is combined with specific types',
        () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/best');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html;q=1.0, */*;q=0.1',
      );
      final response = await request.close();
      final body = json.decode(await utf8.decoder.bind(response).join());
      expect(body['preferred'], 'text/html');
      client.close();
    });

    test('falls back via */* when no specific type matches', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/best');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'image/png;q=1.0, */*;q=0.5',
      );
      final response = await request.close();
      final body = json.decode(await utf8.decoder.bind(response).join());
      expect(body['preferred'], 'application/json');
      client.close();
    });
  });

  group('Gzip headers', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/text',
              middleware: (r) async =>
                  Response.ok(body: '{"long":"${'x' * 200}"}')),
          RouteHttp.get('/binary',
              middleware: (r) async =>
                  const Response.ok(body: [0, 1, 2, 3, 4])),
        ],
        port: 0,
        logConfig: LogConfig.none,
        enableGzip: true,
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('sets Vary header when gzip is applied', () async {
      final client = HttpClient()..autoUncompress = false;
      final request = await client.get('localhost', port, '/text');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
      expect(response.headers.value(HttpHeaders.varyHeader), 'Accept-Encoding');
      client.close();
    });

    test('does not gzip binary responses', () async {
      final client = HttpClient()..autoUncompress = false;
      final request = await client.get('localhost', port, '/binary');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), isNull);
      client.close();
    });
  });

  group('Request timeout', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/slow', middleware: (r) async {
            await Future<void>.delayed(const Duration(milliseconds: 120));
            return const Response.ok(body: {'ok': true});
          }),
          RouteHttp.get('/fast',
              middleware: (r) async => const Response.ok(body: {'ok': true})),
        ],
        port: 0,
        logConfig: LogConfig.none,
        requestTimeout: const Duration(milliseconds: 60),
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('returns 408 when route exceeds requestTimeout', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/slow');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestTimeout);
      client.close();
    });

    test('returns success when route completes before timeout', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/fast');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      client.close();
    });
  });

  group('Graceful shutdown', () {
    test('server stops accepting connections after close', () async {
      final server = Sparky.single(
        routes: [
          RouteHttp.get('/ping',
              middleware: (r) async => const Response.ok(body: 'pong')),
        ],
        port: 0,
        logConfig: LogConfig.none,
      );
      await server.ready;
      final port = server.actualPort;

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

  group('Timeout cooperative cancellation', () {
    late Sparky server;
    late int port;
    late Completer<bool> cancelledCompleter;

    setUp(() async {
      cancelledCompleter = Completer<bool>();
      server = Sparky.single(
        routes: [
          RouteHttp.get('/slow-check', middleware: (r) async {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            cancelledCompleter.complete(r.isCancelled);
            return const Response.ok(body: {'ok': true});
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
        requestTimeout: const Duration(milliseconds: 50),
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() async {
      await server.close();
    });

    test('marks request as cancelled when timeout fires', () async {
      final client = HttpClient();
      final request = await client.get('localhost', port, '/slow-check');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestTimeout);

      final wasCancelled =
          await cancelledCompleter.future.timeout(const Duration(seconds: 2));
      expect(wasCancelled, isTrue);
      client.close();
    });
  });

  group('Cache skips stream responses', () {
    late Sparky server;
    late int port;

    tearDown(() async {
      await server.close();
    });

    test('does not cache stream-based responses', () async {
      var hits = 0;
      server = Sparky.single(
        routes: [
          RouteHttp.get('/stream', middleware: (r) async {
            hits++;
            final bytes = utf8.encode('{"hit":$hits}');
            return Response.ok(
              body: Stream<List<int>>.value(bytes),
              contentType: ContentType.json,
            );
          }),
        ],
        port: 0,
        logConfig: LogConfig.none,
        cacheTtl: const Duration(seconds: 10),
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      var req = await client.get('localhost', port, '/stream');
      var resp = await req.close();
      var body = await utf8.decoder.bind(resp).join();
      expect(json.decode(body)['hit'], 1);

      req = await client.get('localhost', port, '/stream');
      resp = await req.close();
      body = await utf8.decoder.bind(resp).join();
      expect(json.decode(body)['hit'], 2);

      expect(hits, 2);
      client.close();
    });
  });

  group('Gzip for stream responses', () {
    late Sparky server;
    late int port;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sparky-gzip-stream-');
      await File('${tempDir.path}/page.html')
          .writeAsString('<html><body>Hello World!</body></html>');
      await File('${tempDir.path}/logo.png')
          .writeAsBytes(List.generate(100, (i) => i % 256));
    });

    tearDown(() async {
      await server.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('gzip-compresses text static file when client accepts gzip', () async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/api',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        enableGzip: true,
        pipelineBefore: Pipeline()
          ..add(StaticFiles(
            urlPath: '/static',
            directory: tempDir.path,
          ).createMiddleware()),
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient()..autoUncompress = false;
      final request = await client.get('localhost', port, '/static/page.html');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      final rawBytes = <int>[];
      await response.forEach(rawBytes.addAll);
      expect(response.statusCode, 200);
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
      final decompressed = utf8.decode(gzip.decode(rawBytes));
      expect(decompressed, contains('Hello World!'));
      client.close();
    });

    test('does not gzip-compress binary static file', () async {
      server = Sparky.single(
        routes: [
          RouteHttp.get('/api',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        enableGzip: true,
        pipelineBefore: Pipeline()
          ..add(StaticFiles(
            urlPath: '/static',
            directory: tempDir.path,
          ).createMiddleware()),
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient()..autoUncompress = false;
      final request = await client.get('localhost', port, '/static/logo.png');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), isNull);
      client.close();
    });
  });

  group('CORS origin resolution', () {
    late Sparky server;
    late int port;

    test('reflects matching origin from multi-origin config', () async {
      const cors = CorsConfig(
        allowOrigins: ['http://foo.com', 'http://bar.com'],
      );
      final pipeline = Pipeline()..add(cors.createMiddleware());
      server = Sparky.single(
        routes: [
          RouteHttp.get('/test',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        pipelineBefore: pipeline,
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      final request = await client.get('localhost', port, '/test');
      request.headers.set('Origin', 'http://foo.com');
      final response = await request.close();
      expect(response.headers.value('Access-Control-Allow-Origin'),
          'http://foo.com');
      expect(response.headers.value('Vary'), 'Origin');
      client.close();
      await server.close();
    });

    test('does not set origin header when request origin is not allowed',
        () async {
      const cors = CorsConfig(
        allowOrigins: ['http://foo.com'],
      );
      final pipeline = Pipeline()..add(cors.createMiddleware());
      server = Sparky.single(
        routes: [
          RouteHttp.get('/test',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        pipelineBefore: pipeline,
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      final request = await client.get('localhost', port, '/test');
      request.headers.set('Origin', 'http://evil.com');
      final response = await request.close();
      expect(response.headers.value('Access-Control-Allow-Origin'), isNull);
      client.close();
      await server.close();
    });

    test('wildcard config returns * regardless of origin', () async {
      const cors = CorsConfig();
      final pipeline = Pipeline()..add(cors.createMiddleware());
      server = Sparky.single(
        routes: [
          RouteHttp.get('/test',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        pipelineBefore: pipeline,
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      final request = await client.get('localhost', port, '/test');
      request.headers.set('Origin', 'http://anything.com');
      final response = await request.close();
      expect(response.headers.value('Access-Control-Allow-Origin'), '*');
      client.close();
      await server.close();
    });

    test(
        'credentials with wildcard reflects request origin instead of * (CORS spec)',
        () async {
      const cors = CorsConfig(
        allowCredentials: true,
      );
      final pipeline = Pipeline()..add(cors.createMiddleware());
      server = Sparky.single(
        routes: [
          RouteHttp.get('/test',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        pipelineBefore: pipeline,
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      final request = await client.get('localhost', port, '/test');
      request.headers.set('Origin', 'http://myapp.com');
      final response = await request.close();
      expect(response.headers.value('Access-Control-Allow-Origin'),
          'http://myapp.com');
      expect(
          response.headers.value('Access-Control-Allow-Credentials'), 'true');
      expect(response.headers.value('Vary'), 'Origin');
      client.close();
      await server.close();
    });

    test('credentials with wildcard preflight reflects origin', () async {
      const cors = CorsConfig(
        allowCredentials: true,
      );
      final pipeline = Pipeline()..add(cors.createMiddleware());
      server = Sparky.single(
        routes: [
          RouteHttp.get('/test',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: 0,
        logConfig: LogConfig.none,
        pipelineBefore: pipeline,
      );
      await server.ready;
      port = server.actualPort;

      final client = HttpClient();
      final request = await client.open('OPTIONS', 'localhost', port, '/test');
      request.headers.set('Origin', 'http://myapp.com');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.noContent);
      expect(response.headers.value('Access-Control-Allow-Origin'),
          'http://myapp.com');
      expect(
          response.headers.value('Access-Control-Allow-Credentials'), 'true');
      expect(response.headers.value('Vary'), 'Origin');
      client.close();
      await server.close();
    });
  });

  group('Shared server (single isolate)', () {
    test('server with shared: true works normally', () async {
      final server = Sparky.single(
        routes: [
          RouteHttp.get('/ping',
              middleware: (r) async => const Response.ok(body: 'pong')),
        ],
        port: 0,
        shared: true,
        logConfig: LogConfig.none,
      );
      await server.ready;

      final client = HttpClient();
      final request = await client.get('localhost', server.actualPort, '/ping');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      final body = await utf8.decoder.bind(response).join();
      expect(body, 'pong');
      client.close();
      await server.close();
    });
  });

  group('Sparky.serve (multi-isolate)', () {
    test('serves requests across isolates', () async {
      final cluster = await Sparky.cluster(_createTestServer, isolates: 2);

      final client = HttpClient();
      final request = await client.get('localhost', cluster.port, '/hello');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      final body = json.decode(await utf8.decoder.bind(response).join());
      expect(body['message'], 'Hello from isolate');
      client.close();
      await cluster.close();
    });

    test('cluster.close() frees the port', () async {
      final cluster = await Sparky.cluster(_createTestServer, isolates: 2);
      final port = cluster.port;
      await cluster.close();

      // Port should be free — bind a new server on it
      final server = Sparky.single(
        routes: [
          RouteHttp.get('/check',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        port: port,
        logConfig: LogConfig.none,
      );
      await server.ready;
      expect(server.actualPort, port);
      await server.close();
    });

    test('single isolate mode works (isolates: 1)', () async {
      final cluster = await Sparky.cluster(_createTestServer, isolates: 1);

      final client = HttpClient();
      final request = await client.get('localhost', cluster.port, '/hello');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      client.close();
      await cluster.close();
    });

    test('throws when port: 0 with multiple isolates', () async {
      Sparky portZeroFactory(int index) {
        return Sparky.single(
          port: 0,
          shared: true,
          logConfig: LogConfig.none,
          routes: [
            RouteHttp.get('/test',
                middleware: (r) async => const Response.ok(body: 'ok')),
          ],
        );
      }

      await expectLater(
        Sparky.cluster(portZeroFactory, isolates: 2),
        throwsA(isA<StateError>()),
      );
    });

    test('rollback on factory error cleans up already-spawned isolates',
        () async {
      // Worker factory throws on index 1 — the error is reported via
      // onError and the cluster should rollback, freeing the port.
      await expectLater(
        Sparky.cluster(_failingOnSecondIsolate, isolates: 3),
        throwsA(anything),
      );

      // Port should be free after rollback
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final server = Sparky.single(
        port: 4598,
        logConfig: LogConfig.none,
        routes: [
          RouteHttp.get('/check',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
      );
      await server.ready;
      expect(server.actualPort, 4598);
      await server.close();
    });

    test('graceful shutdown waits for workers before returning', () async {
      final cluster = await Sparky.cluster(_createTestServer, isolates: 2);
      final port = cluster.port;

      // Verify cluster is serving
      final client = HttpClient();
      final request = await client.get('localhost', port, '/hello');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      client.close();

      // Graceful shutdown should complete without hanging
      await cluster.close().timeout(
            const Duration(seconds: 10),
            onTimeout: () => fail('Shutdown timed out — workers may be hanging'),
          );

      // Port should be free after graceful shutdown
      final server = Sparky.single(
        port: port,
        logConfig: LogConfig.none,
        routes: [
          RouteHttp.get('/check',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
      );
      await server.ready;
      expect(server.actualPort, port);
      await server.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // HIGH-PRIORITY FEATURE TESTS
  // ════════════════════════════════════════════════════════════════════

  // ──────────────────────────────────────────────────────────────────
  // 1. SparkyTestClient
  // ──────────────────────────────────────────────────────────────────

  group('SparkyTestClient', () {
    late SparkyTestClient client;

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/hello',
              middleware: (r) async => const Response.ok(body: 'hi')),
          RouteHttp.post('/echo', middleware: (r) async {
            final body = await r.getJsonBody();
            return Response.ok(body: body);
          }),
          RouteHttp.put('/put',
              middleware: (r) async => const Response.ok(body: 'put-ok')),
          RouteHttp.patch('/patch',
              middleware: (r) async => const Response.ok(body: 'patch-ok')),
          RouteHttp.delete('/del',
              middleware: (r) async => const Response.ok(body: 'del-ok')),
          RouteHttp.get('/headers', middleware: (r) async {
            final custom = r.headers.value('x-custom');
            return Response.ok(body: {'header': custom});
          }),
        ],
      );
    });

    tearDown(() => client.close());

    test('GET returns 200 with correct body', () async {
      final res = await client.get('/hello');
      expect(res.statusCode, 200);
      expect(res.body, 'hi');
    });

    test('POST with JSON body', () async {
      final res = await client.post('/echo', body: {'name': 'sparky'});
      expect(res.statusCode, 200);
      final json = res.jsonBody as Map<String, dynamic>;
      expect(json['name'], 'sparky');
    });

    test('PUT request', () async {
      final res = await client.put('/put');
      expect(res.statusCode, 200);
      expect(res.body, 'put-ok');
    });

    test('PATCH request', () async {
      final res = await client.patch('/patch');
      expect(res.statusCode, 200);
      expect(res.body, 'patch-ok');
    });

    test('DELETE request', () async {
      final res = await client.delete('/del');
      expect(res.statusCode, 200);
      expect(res.body, 'del-ok');
    });

    test('non-existent route returns 404', () async {
      final res = await client.get('/nope');
      expect(res.statusCode, 404);
    });

    test('custom headers are forwarded', () async {
      final res = await client.get('/headers', headers: {'x-custom': 'test'});
      expect(res.statusCode, 200);
      final json = res.jsonBody as Map<String, dynamic>;
      expect(json['header'], 'test');
    });

    test('baseUrl contains the port', () {
      expect(client.baseUrl, contains('http://localhost:'));
      expect(client.port, greaterThan(0));
    });

    test('from() wraps an existing server', () async {
      final server = Sparky.single(
        port: 0,
        logConfig: LogConfig.none,
        routes: [
          RouteHttp.get('/test',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
      );
      await server.ready;

      final fromClient = SparkyTestClient.from(server);
      final res = await fromClient.get('/test');
      expect(res.statusCode, 200);
      expect(res.body, 'ok');
      await fromClient.close();
    });

    test('TestResponse.contentType returns content type', () async {
      final res = await client.get('/hello');
      expect(res.contentType, isNotNull);
      expect(res.contentType!.primaryType, 'application');
      expect(res.contentType!.subType, 'json');
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // 2. Structured error handling (HttpException)
  // ──────────────────────────────────────────────────────────────────

  group('HttpException classes', () {
    test('BadRequest has status 400', () {
      expect(const BadRequest().statusCode, HttpStatus.badRequest);
      expect(const BadRequest().message, 'Bad Request');
    });

    test('Unauthorized has status 401', () {
      expect(const Unauthorized().statusCode, HttpStatus.unauthorized);
    });

    test('Forbidden has status 403', () {
      expect(const Forbidden().statusCode, HttpStatus.forbidden);
    });

    test('NotFound has status 404', () {
      expect(const NotFound().statusCode, HttpStatus.notFound);
    });

    test('MethodNotAllowed has status 405', () {
      expect(const MethodNotAllowed().statusCode, HttpStatus.methodNotAllowed);
    });

    test('Conflict has status 409', () {
      expect(const Conflict().statusCode, HttpStatus.conflict);
    });

    test('UnprocessableEntity has status 422', () {
      expect(const UnprocessableEntity().statusCode,
          HttpStatus.unprocessableEntity);
    });

    test('TooManyRequests has status 429', () {
      expect(const TooManyRequests().statusCode, HttpStatus.tooManyRequests);
    });

    test('InternalServerError has status 500', () {
      expect(const InternalServerError().statusCode,
          HttpStatus.internalServerError);
    });

    test('BadGateway has status 502', () {
      expect(const BadGateway().statusCode, HttpStatus.badGateway);
    });

    test('ServiceUnavailable has status 503', () {
      expect(
          const ServiceUnavailable().statusCode, HttpStatus.serviceUnavailable);
    });

    test('toJson includes errorCode and message', () {
      const e = NotFound(message: 'User not found');
      final json = e.toJson();
      expect(json['errorCode'], '404');
      expect(json['message'], 'User not found');
    });

    test('toJson includes details when provided', () {
      const e = BadRequest(
        message: 'Invalid input',
        details: {'field': 'email'},
      );
      final json = e.toJson();
      expect(json['errorCode'], '400');
      expect(json['message'], 'Invalid input');
      expect(json['field'], 'email');
    });

    test('toString returns readable format', () {
      const e = NotFound(message: 'User not found');
      expect(e.toString(), 'HttpException(404, User not found)');
    });

    test('custom HttpException with arbitrary status code', () {
      const e = HttpException(418, "I'm a teapot");
      expect(e.statusCode, 418);
      expect(e.message, "I'm a teapot");
    });
  });

  group('HttpException integration', () {
    late SparkyTestClient client;

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/not-found', middleware: (r) {
            throw const NotFound(message: 'User not found');
          }),
          RouteHttp.get('/bad-request', middleware: (r) {
            throw const BadRequest(
              message: 'Invalid email',
              details: {'field': 'email'},
            );
          }),
          RouteHttp.get('/forbidden', middleware: (r) {
            throw const Forbidden(message: 'Access denied');
          }),
          RouteHttp.get('/unauthorized', middleware: (r) {
            throw const Unauthorized();
          }),
          RouteHttp.get('/conflict', middleware: (r) {
            throw const Conflict(message: 'Duplicate entry');
          }),
          RouteHttp.get('/internal-error', middleware: (r) {
            throw const InternalServerError(message: 'Something broke');
          }),
          RouteHttp.get('/custom-error', middleware: (r) {
            throw const HttpException(418, "I'm a teapot");
          }),
        ],
      );
    });

    tearDown(() => client.close());

    test('NotFound returns 404 with JSON body', () async {
      final res = await client.get('/not-found');
      expect(res.statusCode, 404);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['errorCode'], '404');
      expect(body['message'], 'User not found');
    });

    test('BadRequest returns 400 with details', () async {
      final res = await client.get('/bad-request');
      expect(res.statusCode, 400);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['errorCode'], '400');
      expect(body['message'], 'Invalid email');
      expect(body['field'], 'email');
    });

    test('Forbidden returns 403', () async {
      final res = await client.get('/forbidden');
      expect(res.statusCode, 403);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['message'], 'Access denied');
    });

    test('Unauthorized returns 401', () async {
      final res = await client.get('/unauthorized');
      expect(res.statusCode, 401);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['message'], 'Unauthorized');
    });

    test('Conflict returns 409', () async {
      final res = await client.get('/conflict');
      expect(res.statusCode, 409);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['message'], 'Duplicate entry');
    });

    test('InternalServerError returns 500', () async {
      final res = await client.get('/internal-error');
      expect(res.statusCode, 500);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['message'], 'Something broke');
    });

    test('custom HttpException returns correct status code', () async {
      final res = await client.get('/custom-error');
      expect(res.statusCode, 418);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['errorCode'], '418');
      expect(body['message'], "I'm a teapot");
    });

    test('unhandled exception returns 500 generic error', () async {
      final c = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/crash', middleware: (r) {
            throw Exception('unexpected');
          }),
        ],
      );
      final res = await c.get('/crash');
      expect(res.statusCode, 500);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['errorCode'], '500');
      expect(body['message'], 'Internal Server Error');
      await c.close();
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // 3. Dependency Injection per request
  // ──────────────────────────────────────────────────────────────────

  group('Dependency injection', () {
    late SparkyTestClient client;

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/di-ok', middleware: (r) async {
            final user = r.read<String>();
            return Response.ok(body: {'user': user});
          }, guards: [
            (r) async {
              r.provide<String>('admin');
              return null;
            }
          ]),
          RouteHttp.get('/di-missing', middleware: (r) async {
            final user = r.read<String>();
            return Response.ok(body: {'user': user});
          }),
          RouteHttp.get('/di-tryread', middleware: (r) async {
            final user = r.tryRead<String>();
            return Response.ok(body: {'user': user ?? 'none'});
          }),
          RouteHttp.get('/di-tryread-provided', middleware: (r) async {
            final user = r.tryRead<String>();
            return Response.ok(body: {'user': user ?? 'none'});
          }, guards: [
            (r) async {
              r.provide<String>('alice');
              return null;
            }
          ]),
          RouteHttp.get('/di-multi', middleware: (r) async {
            final name = r.read<String>();
            final count = r.read<int>();
            return Response.ok(body: {'name': name, 'count': count});
          }, guards: [
            (r) async {
              r.provide<String>('bob');
              r.provide<int>(42);
              return null;
            }
          ]),
        ],
      );
    });

    tearDown(() => client.close());

    test('guard provides value, handler reads it', () async {
      final res = await client.get('/di-ok');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['user'], 'admin');
    });

    test('read throws StateError when no value provided', () async {
      final res = await client.get('/di-missing');
      // The StateError is an unhandled exception -> 500
      expect(res.statusCode, 500);
    });

    test('tryRead returns null when no value provided', () async {
      final res = await client.get('/di-tryread');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['user'], 'none');
    });

    test('tryRead returns value when provided', () async {
      final res = await client.get('/di-tryread-provided');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['user'], 'alice');
    });

    test('multiple types can be provided and read', () async {
      final res = await client.get('/di-multi');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['name'], 'bob');
      expect(body['count'], 42);
    });
  });

  group('Dependency injection edge cases', () {
    late SparkyTestClient client;

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/di-override', middleware: (r) async {
            final value = r.read<String>();
            return Response.ok(body: {'value': value});
          }, guards: [
            (r) async {
              r.provide<String>('first');
              r.provide<String>('second');
              return null;
            }
          ]),
          RouteHttp.get('/di-generics', middleware: (r) async {
            final strings = r.read<List<String>>();
            final ints = r.read<List<int>>();
            return Response.ok(body: {
              'strings': strings,
              'ints': ints,
            });
          }, guards: [
            (r) async {
              r.provide<List<String>>(['a', 'b']);
              r.provide<List<int>>([1, 2]);
              return null;
            }
          ]),
          RouteHttp.get('/di-tryread-after-provide', middleware: (r) async {
            final before = r.tryRead<int>();
            r.provide<int>(99);
            final after = r.tryRead<int>();
            return Response.ok(body: {
              'before': before,
              'after': after,
            });
          }),
        ],
      );
    });

    tearDown(() => client.close());

    test('override same type keeps last value', () async {
      final res = await client.get('/di-override');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['value'], 'second');
    });

    test('generic types are stored independently', () async {
      final res = await client.get('/di-generics');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['strings'], ['a', 'b']);
      expect(body['ints'], [1, 2]);
    });

    test('tryRead returns null before provide and value after', () async {
      final res = await client.get('/di-tryread-after-provide');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['before'], isNull);
      expect(body['after'], 99);
    });
  });

  group('Dependency injection via pipeline', () {
    late SparkyTestClient client;

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/pipeline-di', middleware: (r) async {
            final role = r.read<String>();
            return Response.ok(body: {'role': role});
          }),
        ],
        pipelineBefore: Pipeline()
          ..add((r) async {
            r.provide<String>('superuser');
            return null;
          }),
      );
    });

    tearDown(() => client.close());

    test('pipeline middleware provides value to handler', () async {
      final res = await client.get('/pipeline-di');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, dynamic>;
      expect(body['role'], 'superuser');
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // 4. Multipart form-data parsing
  // ──────────────────────────────────────────────────────────────────

  group('Multipart parsing (unit)', () {
    test('parses text fields from multipart body', () async {
      const boundary = '----TestBoundary';
      const body = '------TestBoundary\r\n'
          'Content-Disposition: form-data; name="name"\r\n'
          '\r\n'
          'Sparky\r\n'
          '------TestBoundary\r\n'
          'Content-Disposition: form-data; name="version"\r\n'
          '\r\n'
          '2.1.0\r\n'
          '------TestBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      expect(data.fields['name'], 'Sparky');
      expect(data.fields['version'], '2.1.0');
      expect(data.files, isEmpty);
      expect(data.fileList, isEmpty);
    });

    test('parses file uploads with binary content', () async {
      const boundary = '----TestBoundary';
      // Create some binary content (non-UTF8-safe bytes)
      final binaryContent = Uint8List.fromList([0, 1, 2, 255, 254, 253, 128]);
      final bodyParts = <int>[
        ...utf8.encode('------TestBoundary\r\n'),
        ...utf8.encode(
            'Content-Disposition: form-data; name="avatar"; filename="photo.png"\r\n'),
        ...utf8.encode('Content-Type: image/png\r\n'),
        ...utf8.encode('\r\n'),
        ...binaryContent,
        ...utf8.encode('\r\n'),
        ...utf8.encode('------TestBoundary--\r\n'),
      ];

      final data = await MultipartParser(
          Stream.value(Uint8List.fromList(bodyParts)), boundary)
          .parse();

      expect(data.files.containsKey('avatar'), isTrue);
      final file = data.files['avatar']!;
      expect(file.filename, 'photo.png');
      expect(file.contentType, 'image/png');
      expect(file.fieldName, 'avatar');
      expect(file.bytes, binaryContent);
      expect(file.size, binaryContent.length);
    });

    test('parses mixed fields and files', () async {
      const boundary = 'MixedBoundary';
      const body = '--MixedBoundary\r\n'
          'Content-Disposition: form-data; name="title"\r\n'
          '\r\n'
          'My Document\r\n'
          '--MixedBoundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="doc.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'Hello World\r\n'
          '--MixedBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      expect(data.fields['title'], 'My Document');
      expect(data.files['file']?.filename, 'doc.txt');
      expect(utf8.decode(data.files['file']!.bytes), 'Hello World');
      expect(data.fileList.length, 1);
    });

    test('returns empty MultipartData for empty body', () async {
      final data = await MultipartParser(Stream.value(Uint8List(0)), 'boundary').parse();
      expect(data.fields, isEmpty);
      expect(data.files, isEmpty);
    });

    test('extractBoundary extracts boundary from content-type', () {
      expect(
        extractBoundary('multipart/form-data; boundary=----WebKitFormBoundary'),
        '----WebKitFormBoundary',
      );
    });

    test('extractBoundary returns null for non-multipart', () {
      expect(extractBoundary('application/json'), isNull);
    });

    test('extractBoundary returns null for null input', () {
      expect(extractBoundary(null), isNull);
    });

    test('extractBoundary handles quoted boundary', () {
      expect(
        extractBoundary('multipart/form-data; boundary="my-boundary"'),
        'my-boundary',
      );
    });

    test('UploadedFile has correct size', () {
      final file = UploadedFile(
        fieldName: 'test',
        filename: 'test.bin',
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      expect(file.size, 5);
    });

    test('MultipartData.empty returns empty data', () {
      const data = MultipartData.empty();
      expect(data.fields, isEmpty);
      expect(data.files, isEmpty);
      expect(data.fileList, isEmpty);
    });

    test('parses unquoted header parameters', () async {
      const boundary = 'UnquotedBoundary';
      const body = '--UnquotedBoundary\r\n'
          'Content-Disposition: form-data; name=username\r\n'
          '\r\n'
          'sparky\r\n'
          '--UnquotedBoundary\r\n'
          'Content-Disposition: form-data; name=avatar; filename=photo.jpg\r\n'
          'Content-Type: image/jpeg\r\n'
          '\r\n'
          'jpeg-data\r\n'
          '--UnquotedBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      expect(data.fields['username'], 'sparky');
      expect(data.files['avatar']?.filename, 'photo.jpg');
    });

    test('parses mixed quoted and unquoted parameters', () async {
      const boundary = 'MixBoundary';
      const body = '--MixBoundary\r\n'
          'Content-Disposition: form-data; name="title"; filename=report.pdf\r\n'
          'Content-Type: application/pdf\r\n'
          '\r\n'
          'pdf-bytes\r\n'
          '--MixBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      expect(data.files['title']?.filename, 'report.pdf');
    });

    test('skips parts without Content-Disposition', () async {
      const boundary = 'SkipBoundary';
      const body = '--SkipBoundary\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'orphan data\r\n'
          '--SkipBoundary\r\n'
          'Content-Disposition: form-data; name="valid"\r\n'
          '\r\n'
          'ok\r\n'
          '--SkipBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      expect(data.fields.length, 1);
      expect(data.fields['valid'], 'ok');
    });

    test('handles empty file upload', () async {
      const boundary = 'EmptyFileBoundary';
      const body = '--EmptyFileBoundary\r\n'
          'Content-Disposition: form-data; name="doc"; filename="empty.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          '\r\n'
          '--EmptyFileBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      expect(data.files['doc']?.filename, 'empty.txt');
      expect(data.files['doc']?.bytes.length, 0);
    });

    test('multiple files with same field name keeps last in map', () async {
      const boundary = 'DupBoundary';
      const body = '--DupBoundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'aaa\r\n'
          '--DupBoundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="b.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'bbb\r\n'
          '--DupBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      // Map keeps last, fileList keeps all
      expect(data.files['file']?.filename, 'b.txt');
      expect(data.fileList.length, 2);
      expect(data.fileList[0].filename, 'a.txt');
      expect(data.fileList[1].filename, 'b.txt');
    });

    test('handles fields with special characters in values', () async {
      const boundary = 'SpecialBoundary';
      const body = '--SpecialBoundary\r\n'
          'Content-Disposition: form-data; name="bio"\r\n'
          '\r\n'
          'Line1\r\nLine2\r\némojis: 🎉\r\n'
          '--SpecialBoundary--\r\n';

      final data = await MultipartParser(
        Stream.value(Uint8List.fromList(utf8.encode(body))),
        boundary,
      ).parse();

      expect(data.fields['bio'], contains('Line1'));
      expect(data.fields['bio'], contains('🎉'));
    });
  });

  group('Multipart integration', () {
    late SparkyTestClient client;
    late int port;

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post('/upload', middleware: (r) async {
            final form = await r.getMultipartData();
            return Response.ok(body: {
              'fields': form.fields,
              'fileCount': form.fileList.length,
              'fileNames': form.fileList.map((f) => f.filename).toList(),
            });
          }),
        ],
      );
      port = client.port;
    });

    tearDown(() => client.close());

    test('parses multipart form-data from real HTTP request', () async {
      const body = '------TestBoundaryXYZ\r\n'
          'Content-Disposition: form-data; name="name"\r\n'
          '\r\n'
          'Sparky\r\n'
          '------TestBoundaryXYZ\r\n'
          'Content-Disposition: form-data; name="file"; filename="test.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'file content\r\n'
          '------TestBoundaryXYZ--\r\n';

      final httpClient = HttpClient();
      final request = await httpClient.post('localhost', port, '/upload');
      request.headers.set(
          'content-type', 'multipart/form-data; boundary=----TestBoundaryXYZ');
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      httpClient.close();

      expect(response.statusCode, 200);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final fields = json['fields'] as Map<String, dynamic>;
      expect(fields['name'], 'Sparky');
      expect(json['fileCount'], 1);
      expect((json['fileNames'] as List).first, 'test.txt');
    });

    test('returns empty multipart data for non-multipart request', () async {
      final httpClient = HttpClient();
      final request = await httpClient.post('localhost', port, '/upload');
      request.headers.contentType = ContentType.json;
      request.write('{}');
      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      httpClient.close();

      expect(response.statusCode, 200);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      expect(json['fileCount'], 0);
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // 5. SSE / Streaming responses
  // ──────────────────────────────────────────────────────────────────

  group('SseEvent', () {
    test('encodes data-only event', () {
      const event = SseEvent(data: 'hello');
      final encoded = event.encode();
      expect(encoded, contains('data: hello'));
      expect(encoded.endsWith('\n'), isTrue);
    });

    test('encodes event with type and id', () {
      const event = SseEvent(data: 'payload', event: 'update', id: '42');
      final encoded = event.encode();
      expect(encoded, contains('id: 42'));
      expect(encoded, contains('event: update'));
      expect(encoded, contains('data: payload'));
    });

    test('encodes event with retry', () {
      const event = SseEvent(data: 'retry-test', retry: 3000);
      final encoded = event.encode();
      expect(encoded, contains('retry: 3000'));
      expect(encoded, contains('data: retry-test'));
    });

    test('encodes multi-line data with data: prefix per line', () {
      const event = SseEvent(data: 'line1\nline2\nline3');
      final encoded = event.encode();
      expect(encoded, contains('data: line1'));
      expect(encoded, contains('data: line2'));
      expect(encoded, contains('data: line3'));
    });
  });

  group('SSE integration', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        port: 0,
        logConfig: LogConfig.none,
        routes: [
          RouteHttp.get('/events', middleware: (r) async {
            final stream = Stream.fromIterable([
              const SseEvent(data: 'one', id: '1'),
              const SseEvent(data: 'two', id: '2', event: 'msg'),
              const SseEvent(data: 'three', id: '3'),
            ]);
            return Response.sse(stream);
          }),
        ],
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() => server.close());

    test('SSE response has correct content-type and headers', () async {
      final httpClient = HttpClient();
      final request = await httpClient.get('localhost', port, '/events');
      final response = await request.close();

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.primaryType, 'text');
      expect(response.headers.contentType?.subType, 'event-stream');

      final body = await utf8.decoder.bind(response).join();
      httpClient.close();

      // Verify SSE format
      expect(body, contains('data: one'));
      expect(body, contains('id: 1'));
      expect(body, contains('data: two'));
      expect(body, contains('event: msg'));
      expect(body, contains('data: three'));
      expect(body, contains('id: 3'));
    });

    test('SSE has Cache-Control: no-cache header', () async {
      final httpClient = HttpClient();
      final request = await httpClient.get('localhost', port, '/events');
      final response = await request.close();
      await utf8.decoder.bind(response).join(); // drain

      final cacheControl = response.headers.value('cache-control');
      expect(cacheControl, 'no-cache');
      httpClient.close();
    });
  });

  group('Response.stream', () {
    late Sparky server;
    late int port;

    setUp(() async {
      server = Sparky.single(
        port: 0,
        logConfig: LogConfig.none,
        routes: [
          RouteHttp.get('/stream', middleware: (r) async {
            final chunks = Stream.fromIterable([
              utf8.encode('chunk1'),
              utf8.encode('chunk2'),
              utf8.encode('chunk3'),
            ]);
            return Response.stream(
              body: chunks,
              contentType: ContentType('text', 'plain'),
            );
          }),
        ],
      );
      await server.ready;
      port = server.actualPort;
    });

    tearDown(() => server.close());

    test('streams body correctly', () async {
      final httpClient = HttpClient();
      final request = await httpClient.get('localhost', port, '/stream');
      final response = await request.close();

      expect(response.statusCode, 200);
      final body = await utf8.decoder.bind(response).join();
      httpClient.close();

      expect(body, 'chunk1chunk2chunk3');
    });

    test('stream response has correct content-type', () async {
      final httpClient = HttpClient();
      final request = await httpClient.get('localhost', port, '/stream');
      final response = await request.close();
      await utf8.decoder.bind(response).join(); // drain

      expect(response.headers.contentType?.primaryType, 'text');
      expect(response.headers.contentType?.subType, 'plain');
      httpClient.close();
    });
  });

  group('Response stream properties', () {
    test('isStream is true for stream-based body', () {
      const resp = Response.stream(body: Stream<List<int>>.empty());
      expect(resp.isStream, isTrue);
    });

    test('isStream is false for string body', () {
      const resp = Response.ok(body: 'hello');
      expect(resp.isStream, isFalse);
    });

    test('bodyStream returns stream when body is stream', () {
      const resp = Response.stream(body: Stream<List<int>>.empty());
      expect(resp.bodyStream, isNotNull);
    });

    test('bodyStream returns null for non-stream body', () {
      const resp = Response.ok(body: 'hello');
      expect(resp.bodyStream, isNull);
    });

    test('body throws StateError for stream body', () {
      const resp = Response.stream(body: Stream<List<int>>.empty());
      expect(() => resp.body, throwsA(isA<StateError>()));
    });

    test('bodyBytes throws StateError for stream body', () {
      const resp = Response.stream(body: Stream<List<int>>.empty());
      expect(() => resp.bodyBytes, throwsA(isA<StateError>()));
    });

    test('SSE response is a stream', () {
      final resp = Response.sse(
        Stream.fromIterable([const SseEvent(data: 'test')]),
      );
      expect(resp.isStream, isTrue);
      expect(resp.status, HttpStatus.ok);
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // Security headers (already marked done, adding tests)
  // ──────────────────────────────────────────────────────────────────

  group('Security headers', () {
    late SparkyTestClient client;

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/secure',
              middleware: (r) async => const Response.ok(body: 'ok')),
        ],
        pipelineBefore: Pipeline()
          ..add(const SecurityHeadersConfig().createMiddleware()),
      );
    });

    tearDown(() => client.close());

    test('sets default security headers', () async {
      final res = await client.get('/secure');
      expect(res.statusCode, 200);
      expect(res.headers.value('x-content-type-options'), isNotNull);
      expect(res.headers.value('x-frame-options'), isNotNull);
    });
  });
}
