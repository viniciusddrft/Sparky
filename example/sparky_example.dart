// @author viniciusddrft

import 'dart:io';
import 'package:sparky/sparky.dart';

void main() {
  /// In this sample code, I will demonstrate the ways to create routes using custom classes
  /// that either inherit from Route or use the RouteHttp and RouteWebSocket classes directly.
  /// The example also illustrates a JWT login and the pipeline systems before and after
  /// the main route.

  final authJwt = AuthJwt(secretKey: 'senha');

  final login =
      RouteHttp.get('/login', middleware: (HttpRequest request) async {
    final token = authJwt.generateToken({'username': 'username'});

    return Response.ok(body: '{"token":"$token"}');
  });

  final todo =
      RouteHttp.get('/todo/list', middleware: (HttpRequest request) async {
    return Response.ok(body: '[0,1,2,3,4,5,6,7,8,9]');
  });

  final web = RouteWebSocket(
    '/websocket',
    middlewareWebSocket: (WebSocket socket) async {
      socket.add('Hello Word');
      socket.listen(
        (event) {
          print(event);
        },
        onDone: () {
          socket.close();
        },
      );
    },
  );

  Sparky.server(
      routes: [
        login,
        todo,
        web,
        RouteTest(),
        RouteSocket(),
      ],
      pipelineBefore: Pipeline()
        ..add((HttpRequest request) async {
          if (request.requestedUri.path == '/login') {
            return null;
          } else {
            if (request.headers['token'] != null) {
              if (request.headers['token'] != null &&
                  authJwt.verifyToken(request.headers['token']!.first)) {
                return null;
              } else {
                return Response.unauthorized(body: 'Não autorizado');
              }
            } else {
              return Response.unauthorized(body: 'Envie o token no header');
            }
          }
        }),
      pipelineAfter: Pipeline()
        ..add((request) async {
          print('pipeline after 1 done');
          return null;
        })
        ..add((request) async {
          print('pipeline after 2 done');
          return null;
        }));
}

///  creating routes in other ways with classes

final class RouteTest extends Route {
  RouteTest()
      : super('/test', middleware: (request) async {
          return Response.ok(body: 'test');
        }, acceptedMethods: [
          AcceptedMethods.get,
          AcceptedMethods.post,
        ]);
}

final class RouteSocket extends Route {
  RouteSocket()
      : super('/socket', middlewareWebSocket: (WebSocket webSocket) async {
          webSocket.listen((event) {
            print(event);
          }, onDone: () {
            webSocket.close();
          });
        });
}
