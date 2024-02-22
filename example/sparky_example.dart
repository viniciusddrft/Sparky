// @author viniciusddrft

import 'dart:io';
import 'package:sparky/sparky.dart';

void main() {
  final authJwt = AuthJwt(secretKey: 'senha');
  String? token;
  final login =
      RouteHttp.get('/login', middleware: (HttpRequest request) async {
    token = authJwt.generateToken({'username': 'username'});

    return Response.ok(body: '{"token":"$token"}');
  });

  final todo =
      RouteHttp.get('/todo/list', middleware: (HttpRequest request) async {
    return Response.ok(body: '[]');
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
          if (token != null && authJwt.verifyToken(token!)) {
            return null;
          } else {
            return Response.unauthorized(body: 'Não autorizado');
          }
        }
      }),
  );
}
