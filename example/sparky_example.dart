// @author viniciusddrft

import 'dart:io';
import 'dart:math';
import 'package:sparky/sparky.dart';

void main() {
  /// In this sample code, I will demonstrate the ways to create routes using custom classes
  /// that either inherit from Route or use the RouteHttp and RouteWebSocket classes directly.
  /// The example also illustrates JWT login with expiration, CORS support, path parameters,
  /// route groups, JSON body parsing, and the pipeline systems before and after the main route.

  const authJwt = AuthJwt(secretKey: 'senha');

  final login =
      RouteHttp.post('/login', middleware: (HttpRequest request) async {
    final data = await request.getJsonBody();

    final token = authJwt.generateToken(
      {'username': data['user'] ?? '', 'password': data['pass'] ?? ''},
      expiresIn: const Duration(hours: 2),
    );

    return Response.ok(body: {'token': token});
  });

  final todo =
      RouteHttp.get('/todo/list', middleware: (HttpRequest request) async {
    return const Response.ok(body: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
  });

  final random =
      RouteHttp.get('/random', middleware: (HttpRequest request) async {
    final value = Random().nextInt(100);
    return Response.ok(body: {'value': value});
  });

  /// Dynamic route with path parameters
  final userById =
      RouteHttp.get('/users/:id', middleware: (HttpRequest request) async {
    final userId = request.pathParams['id'];
    return Response.ok(body: {'userId': userId, 'name': 'User $userId'});
  });

  final web = RouteWebSocket(
    '/websocket',
    middlewareWebSocket: (WebSocket socket) async {
      socket.add('Hello World');
      socket.listen(
        print,
        onDone: () {
          socket.close();
        },
      );
    },
  );

  /// Route groups for API versioning
  final apiV1Routes = RouteGroup('/api/v1', routes: [
    RouteHttp.get('/status',
        middleware: (r) async => const Response.ok(body: {'status': 'ok'})),
    RouteHttp.get('/health',
        middleware: (r) async => const Response.ok(body: {'healthy': true})),
  ]);

  /// CORS configuration
  const cors = CorsConfig(
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  );

  Sparky.server(
    routes: [
      login,
      todo,
      web,
      random,
      userById,
      RouteTest(),
      RouteSocket(),
      ...apiV1Routes.flatten(),
    ],
    pipelineBefore: Pipeline()
      ..add(cors.createMiddleware())
      ..add(((request) async {
        login.onUpdate();

        if (request.uri.path == login.name) return null;

        final authHeader = request.headers.value('Authorization');
        if (authHeader != null && authJwt.verifyToken(authHeader)) {
          final payload = authJwt.decodePayload(authHeader);
          print('Authenticated user: ${payload?['username']}');
          return null;
        }

        return const Response.forbidden(
            body: {'error': 'Missing or invalid authorization'});
      }))
      ..add((request) async {
        if (request.uri.path == random.name) {
          random.onUpdate();
        }
        return null;
      }),
    pipelineAfter: Pipeline()
      ..add((request) async {
        print('pipeline after 1 done');
        return null;
      })
      ..add((request) async {
        print('pipeline after 2 done');
        return null;
      }),
  );
}

/// Creating routes in other ways with classes

final class RouteTest extends Route {
  RouteTest()
      : super('/test', middleware: (request) async {
          return const Response.ok(body: 'test');
        }, acceptedMethods: [
          AcceptedMethods.get,
          AcceptedMethods.post,
        ]);
}

final class RouteSocket extends Route {
  RouteSocket()
      : super('/socket', middlewareWebSocket: (WebSocket webSocket) async {
          webSocket.listen(print, onDone: () {
            webSocket.close();
          });
        });
}
