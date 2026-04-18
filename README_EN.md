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
- File upload with robust multipart parser (binary-safe)
- Server-Sent Events (SSE) and response streaming
- Structured error handling with typed exceptions (`NotFound`, `BadRequest`, `Forbidden`, etc.)
- Per-request dependency injection (`provide<T>` / `read<T>` / `tryRead<T>`)
- Multi-isolate with `Sparky.cluster()` for multi-core scaling
- Helmet-style security headers with `SecurityHeadersConfig`
- Automatic **OpenAPI 3.0 + Swagger UI** documentation (`/openapi.json`, `/docs`)
- **CSRF** double-submit cookie protection with `CsrfConfig`
- **Prometheus** metrics ready for scrape (`MetricsConfig`, `/metrics` endpoint)
- **Health checks** liveness/readiness (`HealthCheckConfig`, `/health` and `/ready`)
- **Task scheduling** with cron and fixed interval (`SchedulerConfig`, `ScheduledTask`)
- Test utilities with `SparkyTestClient`

## How to Use

### Creating a simple route

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';

void main() {
  final route1 = RouteHttp.get('/hello', middleware: (request) async {
    return const Response.ok(body: 'Hello World');
  });

  Sparky.single(routes: [route1]);
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

Sparky.single(routes: [
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
  Sparky.single(routes: [RouteTest(), RouteSocket()]);
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

  return Response.ok(body: {'received': json});
});
```

### File upload (multipart/form-data)

Robust parser that operates on raw bytes (binary-safe). Supports multiple files and text fields.

```dart
final upload = RouteHttp.post('/upload', middleware: (request) async {
  final form = await request.getMultipartData();

  // Text fields
  final description = form.fields['description'];

  // Files
  for (final file in form.fileList) {
    print('${file.filename} (${file.size} bytes, ${file.contentType})');
    // file.bytes contains the Uint8List with the binary data
  }

  // Or access by field name
  final avatar = form.files['avatar'];

  return Response.ok(body: {'filesReceived': form.fileList.length});
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
Sparky.single(
  routes: [...],
  ip: '0.0.0.0',
  port: 8080,
);
```

### Creating pipelines

You can add N middlewares to pipelines.

```dart
Sparky.single(
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
Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(cors.createMiddleware()),
);
```

### Logging system

By default it shows and saves logs. You can configure the type, mode and file path.

```dart
Sparky.single(
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

Sparky.single(routes: [websocket]);
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

Sparky.single(
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

Sparky.single(
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
Sparky.single(
  routes: [...],
  cacheTtl: const Duration(seconds: 30),
  cacheMaxEntries: 500,
);
```

### Body size and timeout

```dart
Sparky.single(
  routes: [...],
  maxBodySize: 10 * 1024 * 1024, // 10 MB
  requestTimeout: const Duration(seconds: 10),
);
```

### Serving static files

```dart
Sparky.single(
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
Sparky.single(
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

Sparky.single(
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

Sparky.single(
  routes: [...],
  securityContext: context,
);
```

### Server-Sent Events (SSE)

```dart
final sse = RouteHttp.get('/events', middleware: (request) async {
  final events = Stream.periodic(
    const Duration(seconds: 1),
    (i) => SseEvent(data: 'tick ${i + 1}', id: '${i + 1}', event: 'tick'),
  ).take(10);
  return Response.sse(events);
});
```

For large file streaming or downloads:

```dart
final download = RouteHttp.get('/download-csv', middleware: (request) async {
  final file = File('report.csv');
  return Response.stream(
    body: file.openRead(),
    contentType: ContentType('text', 'csv'),
    headers: {'Content-Disposition': 'attachment; filename="report.csv"'},
  );
});
```

### Structured error handling

Typed exceptions that automatically map to HTTP status codes with a standardized JSON body.

```dart
RouteHttp.get('/users/:id', middleware: (request) async {
  final id = request.pathParams['id'];
  final user = await findUser(id);

  if (user == null) {
    throw NotFound(message: 'User not found', details: {'id': id!});
    // Returns 404 with {"errorCode": "404", "message": "User not found", "id": "..."}
  }

  return Response.ok(body: user);
});
```

Available exceptions: `BadRequest` (400), `Unauthorized` (401), `Forbidden` (403), `NotFound` (404), `MethodNotAllowed` (405), `Conflict` (409), `UnprocessableEntity` (422), `TooManyRequests` (429), `InternalServerError` (500), `BadGateway` (502), `ServiceUnavailable` (503).

### Per-request dependency injection

Inject dependencies in guards/middlewares and consume them in handlers.

```dart
Future<Response?> authGuard(HttpRequest request) async {
  final user = await authenticate(request);
  if (user == null) return const Response.unauthorized(body: 'Denied');
  request.provide<User>(user); // inject into request
  return null;
}

RouteHttp.get('/profile',
  middleware: (request) async {
    final user = request.read<User>();        // throws if not provided
    final config = request.tryRead<Config>(); // returns null if not provided
    return Response.ok(body: {'name': user.name});
  },
  guards: [authGuard],
);
```

### Helmet-style security headers

Add standard security headers with a single pipeline entry.

```dart
Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(SecurityHeadersConfig().createMiddleware()),
);
```

Default headers: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `Content-Security-Policy: default-src 'self'`, `Referrer-Policy: no-referrer`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, and more. Each header is individually configurable:

```dart
const headers = SecurityHeadersConfig(
  xFrameOptions: 'SAMEORIGIN',
  contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline'",
  strictTransportSecurity: null, // omits the header
);
```

### OpenAPI / Swagger UI

Auto-generate the **OpenAPI 3.0.3** spec from your HTTP routes and serve Swagger UI at `/docs`.

```dart
Sparky.single(
  openApi: const OpenApiConfig(
    info: OpenApiInfo(
      title: 'My API',
      version: '1.0.0',
      description: 'Automatically generated docs',
    ),
  ),
  routes: [...],
);
```

- `GET /openapi.json` — JSON spec
- `GET /docs` — Swagger UI (CDN configurable via `swaggerUiCdnBase`)

Each route becomes a minimal `operation` (just a `200` response). Enrich it with `OpenApiOperation`:

```dart
RouteHttp.post('/users',
  openApi: const OpenApiOperation(
    summary: 'Create a user',
    tags: ['users'],
    parameters: [
      {'name': 'X-Tenant', 'in': 'header', 'required': true, 'schema': {'type': 'string'}},
    ],
  ),
  middleware: (r) async => ...,
);
```

`Validator.openApiBodySchema` + `Validator.openApiOperation` document JSON bodies without duplication. WebSocket-only routes are not included.

> The `/docs` route emits its own `Content-Security-Policy` that whitelists the Swagger UI CDN — it works out-of-the-box even with `SecurityHeadersConfig` enabled.

### CSRF protection

Double-submit cookie protection against CSRF. The middleware sets `sparky_csrf` (a cookie readable by same-origin JS) on safe methods (`GET/HEAD/OPTIONS`) and validates it on `POST/PUT/PATCH/DELETE`.

```dart
Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(CsrfConfig().createMiddleware()),
);
```

The client must send the token back in the `X-CSRF-Token` header — or in a `_csrf` field for `application/x-www-form-urlencoded` / JSON bodies. For `multipart/form-data`, send the token **only in the header** (the body is not read in the middleware). By default, requests carrying `Authorization: Bearer …` **skip** the check (handy for stateless JWT APIs); disable with `ignoreRequestsWithBearer: false`.

For local HTTP dev, disable `cookieSecure`:

```dart
const csrf = CsrfConfig(cookieSecure: false);
```

Missing/invalid token → HTTP `403` with `{"error": "csrf_validation_failed"}`.

### Prometheus metrics

`/metrics` endpoint in Prometheus 0.0.4 text format, with counter, gauge and duration histogram ready to be scraped.

```dart
Sparky.single(
  metrics: MetricsConfig(
    ignorePaths: {'/health', '/ready'}, // don't count probes
  ),
  routes: [...],
);
```

Exposed series (prefix configurable via `namespace`):

- `sparky_http_requests_total{method,status}` — counter
- `sparky_http_requests_in_progress` — gauge
- `sparky_http_request_duration_seconds_bucket{method,le}` — histogram (compute p50/p95/p99 via `histogram_quantile` in Prometheus)

Protect the scrape with `authGuard` (Bearer, IP allowlist, etc):

```dart
MetricsConfig(
  authGuard: (request) async {
    if (request.headers.value('Authorization') != 'Bearer $scrapeToken') {
      return const Response.unauthorized(body: 'denied');
    }
    return null;
  },
);
```

Under `Sparky.cluster`, each isolate exposes its own series — Prometheus aggregates via `sum by (method, status)`.

### Health checks

`/health` (liveness) and `/ready` (readiness) endpoints with pluggable checks and timeout, Kubernetes-friendly.

```dart
Sparky.single(
  health: HealthCheckConfig(
    readinessChecks: {
      'db': () async {
        final ok = await db.ping();
        return ok
            ? const HealthCheckResult.up()
            : const HealthCheckResult.down(message: 'db unreachable');
      },
      'redis': () async => const HealthCheckResult.up(details: {'latencyMs': 2}),
    },
  ),
  routes: [...],
);
```

- Checks run in parallel under `checkTimeout` (default 5s); timeouts and exceptions map to `DOWN`.
- Overall status is the worst individual one (`DOWN > DEGRADED > UP`): `200` when healthy or degraded, `503` when any check is `DOWN`.
- `failReadinessOnDegraded: true` makes `DEGRADED` also return `503`.
- Optional `authGuard` protects the probes (so you don't expose dependency state publicly).

Response body:

```json
{"status":"UP","checks":{"db":{"status":"UP"},"redis":{"status":"UP","details":{"latencyMs":2}}}}
```

### Task scheduling (cron + interval)

Run recurring jobs in-process. 5-field cron (with aliases `jan-dec` / `sun-sat`, ranges, lists and `*/N`) or a fixed `Duration` cadence.

```dart
Sparky.single(
  scheduler: SchedulerConfig(tasks: [
    ScheduledTask(
      name: 'nightly-cleanup',
      expression: '0 3 * * *', // every day at 03:00
      job: () async => await cleanupOldRecords(),
    ),
    ScheduledTask.every(
      interval: const Duration(minutes: 5),
      name: 'heartbeat',
      job: () => print('tick'),
    ),
  ]),
  routes: [...],
);
```

- The scheduler starts on `server.ready` and stops on `server.close()` awaiting in-flight jobs.
- `onError` captures exceptions without tearing down the loop.
- `allowOverlap` prevents pile-up for slow jobs (default `true` for cron, `false` for `every`).
- Under `Sparky.cluster`, each isolate runs its own scheduler — for exactly-once, gate on `isolateIndex == 0` in the factory or use an external lock.

### Multi-isolate (cluster mode)

Scale your server across multiple CPU cores.

```dart
// Factory MUST be a top-level or static function
Sparky createServer(int isolateIndex) {
  return Sparky.single(
    port: 3000,
    shared: true, // required for cluster
    routes: [...],
  );
}

void main() async {
  final cluster = await Sparky.cluster(createServer, isolates: 4);
  print('Running on port ${cluster.port} with 4 isolates');

  // To shut down:
  await cluster.close();
}
```

### Test utilities

`SparkyTestClient` boots the server on an OS-assigned port for collision-free testing.

```dart
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  late SparkyTestClient client;

  setUp(() {
    client = SparkyTestClient(routes: [myRoute]);
  });

  tearDown(() => client.close());

  test('GET /hello returns 200', () async {
    final response = await client.get('/hello');
    expect(response.statusCode, 200);
  });
}
```

### Graceful shutdown

```dart
final server = Sparky.single(routes: [...]);
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
