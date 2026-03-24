# Welcome to Sparky

[Switch to Portuguese](README.md)

Sparky is a Dart package for building REST APIs in a simple way, with support for WebSocket, JWT authentication, CORS, dynamic routes and more.

## Features

- Dynamic routes with path parameters (`:id`)
- Route grouping with prefix (`RouteGroup`)
- Per-route and per-group guards
- Automatic route caching (per HTTP method, with TTL and max entries)
- Configurable CORS support (multi-origin, credentials, `Vary: Origin`)
- Logging system (console, file or both)
- WebSocket support
- JWT authentication with expiration (HS256, no base64url padding, algorithm validation)
- Pipeline before and after the main middleware
- Automatic Map/List to JSON serialization
- Custom headers in Response
- Graceful shutdown
- JSON body, form-data and URL-encoded parsing
- Request body size limit (`maxBodySize`)
- Per-request timeout (`requestTimeout`)
- Gzip compression for normal and stream responses (`enableGzip`, `gzipMinLength`)
- Built-in rate limiting
- Static file serving with `StaticFiles` (ETag, Last-Modified, 304)
- Content negotiation and cookie helpers
- Request body validation (`Validator`)
- Native HTTPS/TLS via `SecurityContext`

## How to Use

### Creating a simple route

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';

void main() {
  final route1 = RouteHttp.get('/hello', middleware: (request) async {
    return const Response.ok(body: 'Hello World');
  });

  Sparky.server(routes: [route1]);
}
```

### Dynamic routes with path parameters

Define dynamic segments with `:param` and access them via `request.pathParams`.

```dart
final userRoute = RouteHttp.get('/users/:id', middleware: (request) async {
  final userId = request.pathParams['id'];
  return Response.ok(body: {'userId': userId, 'name': 'User $userId'});
});

final itemRoute = RouteHttp.get('/items/:category/:itemId', middleware: (request) async {
  return Response.ok(body: {
    'category': request.pathParams['category'],
    'itemId': request.pathParams['itemId'],
  });
});
```

### Route grouping (RouteGroup)

Group routes under a common prefix and use `flatten()` to expand them.

```dart
final apiRoutes = RouteGroup('/api/v1', routes: [
  RouteHttp.get('/users', middleware: (r) async => const Response.ok(body: {'users': []})),
  RouteHttp.get('/products', middleware: (r) async => const Response.ok(body: {'products': []})),
]);

Sparky.server(routes: [
  ...apiRoutes.flatten(), // creates /api/v1/users and /api/v1/products
]);
```

### Creating a route from a class

```dart
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

void main() {
  Sparky.server(routes: [RouteTest(), RouteSocket()]);
}
```

### Automatic JSON serialization

The `Response` body accepts String, Map or List. Non-String values are automatically serialized.

```dart
final route = RouteHttp.get('/data', middleware: (request) async {
  return const Response.ok(body: {'message': 'hello', 'items': [1, 2, 3]});
});
```

### Body parsing (JSON, form-data, URL-encoded)

```dart
final route = RouteHttp.post('/submit', middleware: (request) async {
  // JSON body (application/json)
  final json = await request.getJsonBody();

  // URL-encoded (application/x-www-form-urlencoded)
  final form = await request.getFormData();

  // Multipart form-data
  final multipart = await request.getBodyParams();

  return Response.ok(body: {'received': json});
});
```

### Custom headers in Response

```dart
final route = RouteHttp.get('/download', middleware: (request) async {
  return const Response.ok(
    body: 'content',
    headers: {
      'X-Custom-Header': 'value',
      'Cache-Control': 'no-cache',
    },
  );
});
```

### Request body validation

```dart
final schema = Validator({
  'name': [isRequired, isString, minLength(3)],
  'email': [isRequired, isString, isEmail],
  'age': [isRequired, isNum, min(18)],
});

RouteHttp.post('/register', middleware: (request) async {
  final body = await request.getJsonBody();
  final errors = schema.validate(body);
  if (errors.isNotEmpty) {
    return Response.badRequest(body: {'errors': errors});
  }
  return Response.created(body: {'ok': true});
});
```

### Per-route guards

Guards are middlewares that run before the route handler. If any guard returns a `Response`, the route handler is skipped.

```dart
Future<Response?> authGuard(HttpRequest request) async {
  final token = request.headers.value('Authorization');
  if (token != null && authJwt.verifyToken(token)) return null;
  return const Response.unauthorized(body: {'error': 'Unauthorized'});
}

final route = RouteHttp.get('/admin',
  middleware: (r) async => const Response.ok(body: {'admin': true}),
  guards: [authGuard],
);
```

### Customizing IP and port

```dart
Sparky.server(
  routes: [...],
  ip: '0.0.0.0',
  port: 8080,
);
```

### Creating pipelines

You can add N middlewares to pipelines.

```dart
Sparky.server(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add((request) async {
      // Return null to continue or a Response to stop
      return null;
    }),
  pipelineAfter: Pipeline()
    ..add((request) async {
      print('Executed after the route');
      return null;
    }),
);
```

### CORS support

```dart
// Multiple origins — the middleware reflects the request origin if allowed
const cors = CorsConfig(
  allowOrigins: ['https://myapp.com', 'https://admin.myapp.com'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
);

// With credentials (allowOrigins: ['*'] reflects the request origin instead of *)
const corsWithCreds = CorsConfig(allowCredentials: true);

// Or use CorsConfig.permissive() for development
Sparky.server(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(cors.createMiddleware()),
);
```

### Logging system

By default it shows and saves logs. You can configure the type, mode and file path.

```dart
Sparky.server(
  routes: [...],
  logConfig: LogConfig.showAndWriteLogs,
  logType: LogType.all,
  logFilePath: 'server.log', // default: 'logs.txt'
);
```

### Using WebSockets

```dart
final websocket = RouteWebSocket(
  '/ws',
  middlewareWebSocket: (WebSocket socket) async {
    socket.add('Hello World');
    socket.listen(
      print,
      onDone: () => socket.close(),
    );
  },
);

Sparky.server(routes: [websocket]);
```

### JWT authentication with expiration

```dart
const authJwt = AuthJwt(secretKey: 'my-secret-key');

final login = RouteHttp.post('/login', middleware: (request) async {
  final data = await request.getJsonBody();

  final token = authJwt.generateToken(
    {'username': data['user']},
    expiresIn: const Duration(hours: 2),
  );

  return Response.ok(body: {'token': token});
});

Sparky.server(
  routes: [login],
  pipelineBefore: Pipeline()
    ..add((request) async {
      if (request.uri.path == '/login') return null;

      final token = request.headers.value('Authorization');
      if (token != null && authJwt.verifyToken(token)) {
        final payload = authJwt.decodePayload(token);
        print('User: ${payload?['username']}');
        return null;
      }

      return const Response.unauthorized(
        body: {'error': 'Missing or invalid token'},
      );
    }),
);
```

### Route caching

Caching is automatic and differentiated by HTTP method. After the first execution, the route returns the cached response. Call `onUpdate()` to invalidate the cache.

```dart
final random = RouteHttp.get('/random', middleware: (request) async {
  final value = Random().nextInt(100);
  return Response.ok(body: {'value': value});
});

Sparky.server(
  routes: [random],
  pipelineBefore: Pipeline()
    ..add((request) async {
      random.onUpdate(); // invalidates cache, runs route code
      return null;
    }),
);
```

You can also configure TTL and max cache entries:

```dart
Sparky.server(
  routes: [...],
  cacheTtl: const Duration(seconds: 30),
  cacheMaxEntries: 500,
);
```

### Body size and timeout

```dart
Sparky.server(
  routes: [...],
  maxBodySize: 10 * 1024 * 1024, // 10 MB
  requestTimeout: const Duration(seconds: 10),
);
```

### Serving static files

```dart
Sparky.server(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(
      StaticFiles(
        urlPath: '/public',
        directory: './static',
        maxFileSize: 5 * 1024 * 1024, // optional
      ).createMiddleware(),
    ),
);
```

### Gzip

```dart
Sparky.server(
  routes: [...],
  enableGzip: true,
  gzipMinLength: 1024,
);
```

### Rate limiting

```dart
final limiter = RateLimiter(
  maxRequests: 100,
  window: const Duration(minutes: 1),
  trustProxyHeaders: true, // only behind a trusted proxy
);

Sparky.server(
  routes: [...],
  pipelineBefore: Pipeline()..add(limiter.createMiddleware()),
);
```

### Content negotiation

```dart
RouteHttp.get('/data', middleware: (request) async {
  final preferred = request.preferredType(
    const ['application/json', 'text/html'],
  );
  if (preferred == 'text/html') {
    return Response.ok(body: '<h1>ok</h1>', contentType: ContentType.html);
  }
  return Response.ok(body: {'ok': true}, contentType: ContentType.json);
});
```

### Cookies

```dart
RouteHttp.get('/set-cookie', middleware: (request) async {
  final cookie = Cookie('session', 'token')
    ..httpOnly = true
    ..secure = true;
  return Response.ok(body: {'ok': true}, cookies: [cookie]);
});
```

### HTTPS/TLS

```dart
final context = SecurityContext()
  ..useCertificateChain('cert.pem')
  ..usePrivateKey('key.pem');

Sparky.server(
  routes: [...],
  securityContext: context,
);
```

### Graceful shutdown

```dart
final server = Sparky.server(routes: [...]);
await server.ready; // wait for server to be ready

// When you want to stop:
await server.close();
```

### Compiling for maximum performance

```bash
dart compile exe main.dart
```

## Contributing

The project is fully open source and contributions are very welcome.
