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
    return Response.ok(body: '[]');
  });

  final web = RouteWebSocket(
    '/oii',
    middlewareWebSocket: (WebSocket socket) async {
      socket.add('fala pow');
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

  Sparky.server(routes: [login, todo, web]);
}
