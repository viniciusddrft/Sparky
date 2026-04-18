// @author viniciusddrft

import 'dart:convert';
import 'dart:io';

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart' hide isList, isMap, matches;

void main() {
  group('sparkyPathToOpenApi', () {
    test('converts :param to brace form', () {
      expect(sparkyPathToOpenApi('/users/:id'), '/users/{id}');
      expect(
        sparkyPathToOpenApi('/users/:userId/posts/:postId'),
        '/users/{userId}/posts/{postId}',
      );
    });

    test('leaves static segments', () {
      expect(sparkyPathToOpenApi('/api/v1/users'), '/api/v1/users');
    });
  });

  group('buildOpenApiDocument', () {
    test('includes path params and methods', () {
      final routes = <Route>[
        RouteHttp.get(
          '/api/items/:id',
          middleware: (r) async => const Response.ok(body: <String, dynamic>{}),
          openApi: const OpenApiOperation(summary: 'Get item'),
        ),
      ];
      final doc = buildOpenApiDocument(
        routes: routes,
        info: const OpenApiInfo(title: 'T', version: '1.0.0'),
        servers: const [OpenApiServer(url: 'http://localhost:8080')],
      );

      expect(doc['openapi'], '3.0.3');
      expect((doc['info'] as Map)['title'], 'T');
      expect((doc['servers'] as List).length, 1);

      final paths = doc['paths'] as Map<String, Object?>;
      expect(paths.containsKey('/api/items/{id}'), isTrue);
      final item = paths['/api/items/{id}']! as Map<String, Object?>;
      final getOp = item['get']! as Map<String, Object?>;
      expect(getOp['summary'], 'Get item');
      final params = getOp['parameters'] as List<dynamic>;
      expect(params.length, 1);
      expect((params.first as Map)['name'], 'id');
      expect((params.first as Map)['in'], 'path');
    });

    test('skips WebSocket-only routes', () {
      final routes = <Route>[
        RouteWebSocket('/ws', middlewareWebSocket: (s) async {}),
        RouteHttp.get('/ping',
            middleware: (r) async => const Response.ok(body: 'pong')),
      ];
      final doc = buildOpenApiDocument(
        routes: routes,
        info: const OpenApiInfo(title: 'T', version: '1.0.0'),
      );
      final paths = doc['paths'] as Map<String, Object?>;
      expect(paths.keys, ['/ping']);
    });

    test('merges user parameters with auto path params', () {
      final routes = <Route>[
        RouteHttp.get(
          '/users/:id',
          middleware: (r) async => const Response.ok(body: <String, dynamic>{}),
          openApi: const OpenApiOperation(
            parameters: [
              {
                'name': 'page',
                'in': 'query',
                'schema': {'type': 'integer'},
              },
              {
                'name': 'id',
                'in': 'path',
                'required': true,
                'schema': {'type': 'integer', 'format': 'int64'},
              },
            ],
          ),
        ),
      ];
      final doc = buildOpenApiDocument(
        routes: routes,
        info: const OpenApiInfo(title: 'T', version: '1.0.0'),
      );
      final op = ((doc['paths'] as Map)['/users/{id}']
          as Map)['get'] as Map<String, Object?>;
      final params = op['parameters'] as List<dynamic>;
      expect(params.length, 2);
      final byName = {
        for (final p in params) (p as Map)['name'] as String: p,
      };
      expect(byName.keys, containsAll(['page', 'id']));
      expect(((byName['id'] as Map)['schema'] as Map)['type'], 'integer');
      expect((byName['page'] as Map)['in'], 'query');
    });

    test('Validator openApiBodySchema maps to operation', () {
      final schema = const Validator(
        {},
        openApiBodySchema: {
          'type': 'object',
          'required': ['name'],
          'properties': {
            'name': {'type': 'string', 'minLength': 3},
          },
        },
      ).openApiOperation;
      expect(schema, isNotNull);
      final rb = schema!.requestBody!['content'] as Map<String, Object?>;
      final jsonContent = rb['application/json'] as Map<String, Object?>;
      expect((jsonContent['schema'] as Map)['type'], 'object');
    });
  });

  group('OpenAPI HTTP routes', () {
    late SparkyTestClient client;

    tearDown(() async {
      await client.close();
    });

    test('GET /openapi.json returns spec', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/hello',
              middleware: (r) async => const Response.ok(body: {'ok': true})),
        ],
        openApi: const OpenApiConfig(
          info: OpenApiInfo(title: 'Test API', version: '0.0.1'),
        ),
      );

      final res = await client.get('/openapi.json');
      expect(res.statusCode, HttpStatus.ok);
      expect(res.contentType?.mimeType, 'application/json');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['openapi'], '3.0.3');
      final paths = json['paths'] as Map<String, dynamic>;
      expect(paths.containsKey('/hello'), isTrue);
      expect(paths.containsKey('/openapi.json'), isFalse);
      expect(paths.containsKey('/docs'), isFalse);
    });

    test('GET /docs returns HTML with Swagger UI', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (r) async => const Response.ok(body: '')),
        ],
        openApi: const OpenApiConfig(
          info: OpenApiInfo(title: 'UI Test', version: '1.0.0'),
          specPath: '/custom-openapi.json',
          docsPath: '/reference',
        ),
      );

      final res = await client.get('/reference');
      expect(res.statusCode, HttpStatus.ok);
      expect(res.contentType?.mimeType, 'text/html');
      expect(res.body, contains('swagger-ui-bundle.js'));
      expect(res.body, contains('/custom-openapi.json'));

      final spec = await client.get('/custom-openapi.json');
      expect(spec.statusCode, HttpStatus.ok);
    });

    test('disabled OpenApiConfig does not add routes', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/only',
              middleware: (r) async => const Response.ok(body: '')),
        ],
        openApi: const OpenApiConfig(
          enabled: false,
          info: OpenApiInfo(title: 'X', version: '1'),
        ),
      );

      final res = await client.get('/openapi.json');
      expect(res.statusCode, HttpStatus.notFound);
    });
  });

  group('Route introspection', () {
    test('pathParameterNames and isHttpRoute', () {
      final http = RouteHttp.get('/a/:id',
          middleware: (r) async => const Response.ok(body: ''));
      expect(http.pathParameterNames, ['id']);
      expect(http.isHttpRoute, isTrue);

      final ws = RouteWebSocket('/w', middlewareWebSocket: (s) async {});
      expect(ws.pathParameterNames, isEmpty);
      expect(ws.isHttpRoute, isFalse);
    });
  });
}
