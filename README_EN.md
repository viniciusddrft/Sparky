# Welcome to Sparky

[Switch to Portuguese](README.md)

Sparky is a package that helps in building rest apis in a simple way with websocket support with jwt authentication.

# Characteristics

- Records system.
- WebSocket support.
- JWT authentication.
- Pipeline before and after the main middleware.

# How to use

## Creating a simple route

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';

void main(){
    // Creation of the route passing through a middleware that receives all the data from the request, and needs to return a response.

    final route1 = RouteHttp.get('/teste', middleware: (request) async {
      return Response.ok(body: 'Hello world');
    });
  
    // initialization of Sparky passing through a list of routes.
    Sparky.server(routes: [route1]);
}
```

## How to customize the ip and port

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';
void main(){
   Sparky.server(
    routes: [...],
    ip: '0.0.0.0',
    port: 8080,
   );
}
```

## How to Create pipeline

You can create Add N middlewares in pipilenes.

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';
void main(){
Sparky.server(
   routes: [...],
   // Execute after executing the route.
   pipelineAfter: Pipeline()..add((request)async => null)..add((request)async => null),
   // Executed before executing the route, it may return null or a Response, if a response is returned it does not execute the main route.
   pipelineBefore: Pipeline()..add((request) async {
     ......
     }),
    );
}
```

## Records system

By default it implicitly has this configuration, but you can change this enum to only show error logs, you can choose between just showing or saving in a 'logs.txt' file

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';
void main(){
   Sparky.server(
    routes: [...],
    logConfig: LogConfig.showAndWriteLogs,
    logType: LogType.all
   );
}
```

## How to use WebSockets

A webSocket route is one created with this RouteWebSocket class and passed in the route list like all others, it is assigned a socket where you can listen and handle all data sent and received on the socket.

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';
void main(){
   final websocket = RouteWebSocket(
    '/test',
    middlewareWebSocket: (WebSocket socket) async {
     socket.add('Hello World');
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
    routes: [websocket],
   );
}
```

## How to do a simple login with JWT

Here a token is generated and before each request it checks if the request is for login rotation and ignores it if it is true, otherwise it checks the login token and returns null, this lets it go to the main route, otherwise it returns an unauthorized response.

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';
void main(){
   final authJwt = AuthJwt(secretKey: 'secretKey');
   token String late end;
 
   final login = RouteHttp.get('/login', middleware: (HttpRequest request) async {
    token = authJwt.generateToken({'username': 'username'});
    return Response.ok(body: '{"token":"$token"}');
   });
 
   Sparky.server(
    routes: [login],
    pipelineBefore: Pipeline()..add((request) async {
     if (request.requestedUri.path == '/login') {
      return null;
     } other {
     if (authJwt.verifyToken(token)) {
      return null;
     } other {
      return Response.unauthorized(body: 'Unauthorized');
     }
    }
   }),
   );
}
```

# How to build to use in the most performant way

Dart is a language compiled for any platform, like the command below, passing through your project file, you will get one that is possibly much more performant.

```bash
dart compile exe main.dart
```

# Vision for the future

The idea is to always keep it simple, not add complexity, the idea is in the next updates to leave simple ways to make certain routes run in a separate isolate using a flag, to achieve greater performance and add tests, the project is completely code open and contributions are very welcome.
