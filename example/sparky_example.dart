// @author viniciusddrft

import 'dart:io';
import 'package:sparky/sparky.dart';

void main() {
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
    routes: [login, todo, web],
    pipelineBefore: Pipeline()
      ..add((request) async {
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
  );
}
