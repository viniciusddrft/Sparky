// @author viniciusddrft

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart' hide isList, isMap, matches;
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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

      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      final server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
      server = Sparky.server(
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
}
