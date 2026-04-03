// @author viniciusddrft

// Sparky 2.1.0 — Example

// Each section below demonstrates one feature independently,
// following the same order as the README.
// Run: dart run example/sparky_example.dart

import 'package:sparky/sparky.dart';
import 'dart:io';

void main() async {
  // ─────────────────────────────────────────────────────────────────────
  // 1. Simple route
  // ─────────────────────────────────────────────────────────────────────
  final hello = RouteHttp.get('/hello', middleware: (request) async {
    return const Response.ok(body: 'Hello World');
  });

  // ─────────────────────────────────────────────────────────────────────
  // 2. Dynamic routes with path parameters
  // ─────────────────────────────────────────────────────────────────────
  final userById = RouteHttp.get('/users/:id', middleware: (request) async {
    final userId = request.pathParams['id'];
    return Response.ok(body: {'userId': userId, 'name': 'User $userId'});
  });

  // ─────────────────────────────────────────────────────────────────────
  // 3. Route group with prefix
  // ─────────────────────────────────────────────────────────────────────
  final apiRoutes = RouteGroup('/api/v1', routes: [
    RouteHttp.get('/status',
        middleware: (r) async => const Response.ok(body: {'status': 'ok'})),
    RouteHttp.get('/items',
        middleware: (r) async => const Response.ok(body: {
              'items': ['a', 'b', 'c']
            })),
  ]);

  // ─────────────────────────────────────────────────────────────────────
  // 4. JSON serialization (Map/List auto-serialized)
  // ─────────────────────────────────────────────────────────────────────
  final data = RouteHttp.get('/data', middleware: (request) async {
    return const Response.ok(body: {
      'message': 'hello',
      'items': [1, 2, 3]
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 5. Body parsing (JSON and form-data)
  // ─────────────────────────────────────────────────────────────────────
  final echo = RouteHttp.post('/echo', middleware: (request) async {
    final json = await request.getJsonBody();
    return Response.ok(body: {'echo': json});
  });

  // ─────────────────────────────────────────────────────────────────────
  // 6. Request body validation
  // ─────────────────────────────────────────────────────────────────────
  final registerSchema = Validator({
    'name': [isRequired, isString, minLength(3)],
    'email': [isRequired, isString, isEmail],
    'age': [isRequired, isNum, min(18)],
  });

  final register = RouteHttp.post('/register', middleware: (request) async {
    final body = await request.getJsonBody();
    final errors = registerSchema.validate(body);
    if (errors.isNotEmpty) {
      return Response.badRequest(body: {'errors': errors});
    }
    return Response.created(body: {'ok': true, 'user': body['name']});
  });

  // ─────────────────────────────────────────────────────────────────────
  // 7. Custom headers
  // ─────────────────────────────────────────────────────────────────────
  final download = RouteHttp.get('/download', middleware: (request) async {
    return const Response.ok(
      body: 'file content',
      headers: {'X-Custom-Header': 'value', 'Cache-Control': 'no-cache'},
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // 8. JWT authentication with expiration
  // ─────────────────────────────────────────────────────────────────────
  const authJwt = AuthJwt(secretKey: 'my-secret-key');

  final login = RouteHttp.post('/login', middleware: (request) async {
    final body = await request.getJsonBody();
    final token = authJwt.generateToken(
      {'username': body['user'] ?? ''},
      expiresIn: const Duration(hours: 2),
    );
    return Response.ok(body: {'token': token});
  });

  // ─────────────────────────────────────────────────────────────────────
  // 9. Guards (per-route auth middleware)
  // ─────────────────────────────────────────────────────────────────────
  Future<Response?> authGuard(HttpRequest request) async {
    final token = request.headers.value('Authorization');
    if (token != null && authJwt.verifyToken(token)) return null;
    return const Response.unauthorized(body: {'error': 'Unauthorized'});
  }

  final admin = RouteHttp.get('/admin',
      middleware: (r) async => const Response.ok(body: {'admin': true}),
      guards: [authGuard]);

  // ─────────────────────────────────────────────────────────────────────
  // 10. WebSocket
  // ─────────────────────────────────────────────────────────────────────
  final websocket = RouteWebSocket(
    '/ws',
    middlewareWebSocket: (WebSocket socket) async {
      socket.add('Hello from Sparky!');
      socket.listen(
        (msg) => socket.add('Echo: $msg'),
        onDone: () => socket.close(),
      );
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // 11. Class-based routes
  // ─────────────────────────────────────────────────────────────────────
  final testRoute = ExampleRoute();

  // ─────────────────────────────────────────────────────────────────────
  // 12. Content negotiation
  // ─────────────────────────────────────────────────────────────────────
  final negotiate = RouteHttp.get('/negotiate', middleware: (request) async {
    final preferred =
        request.preferredType(const ['application/json', 'text/html']);
    if (preferred == 'text/html') {
      return Response.ok(body: '<h1>ok</h1>', contentType: ContentType.html);
    }
    return Response.ok(body: {'ok': true}, contentType: ContentType.json);
  });

  // ─────────────────────────────────────────────────────────────────────
  // 13. Cookies
  // ─────────────────────────────────────────────────────────────────────
  final setCookie = RouteHttp.get('/set-cookie', middleware: (request) async {
    final cookie = Cookie('session', 'abc123')
      ..httpOnly = true
      ..secure = true;
    return Response.ok(body: {'ok': true}, cookies: [cookie]);
  });

  final readCookie = RouteHttp.get('/read-cookie', middleware: (request) async {
    final session = request.getCookie('session');
    return Response.ok(body: {'session': session?.value ?? 'none'});
  });

  // ─────────────────────────────────────────────────────────────────────
  // 14. CORS (multi-origin, credentials)
  // ─────────────────────────────────────────────────────────────────────
  const cors = CorsConfig(
    allowOrigins: ['https://myapp.com', 'https://admin.myapp.com'],
    allowCredentials: true,
  );

  // ─────────────────────────────────────────────────────────────────────
  // 15. Rate limiting
  // ─────────────────────────────────────────────────────────────────────
  final limiter = RateLimiter(
    maxRequests: 100,
    window: const Duration(minutes: 5),
  );

  // ─────────────────────────────────────────────────────────────────────
  // 16. Static files
  // ─────────────────────────────────────────────────────────────────────
  const staticFiles = StaticFiles(
    urlPath: '/public',
    directory: './static',
  );

  // ─────────────────────────────────────────────────────────────────────
  // 17. Start the server with all features
  // ─────────────────────────────────────────────────────────────────────
  final server = Sparky.single(
    routes: [
      hello,
      userById,
      data,
      echo,
      register,
      download,
      login,
      admin,
      websocket,
      testRoute,
      negotiate,
      setCookie,
      readCookie,
      ...apiRoutes.flatten(),
    ],
    port: 3000,
    // Pipelines — CORS, rate limit, static files
    pipelineBefore: Pipeline()
      ..add(cors.createMiddleware())
      ..add(limiter.createMiddleware())
      ..add(staticFiles.createMiddleware()),
    // Logging
    logConfig: LogConfig.showLogs,
    // Security
    maxBodySize: 10 * 1024 * 1024, // 10 MB
    requestTimeout: const Duration(seconds: 30),
    // Gzip
    enableGzip: true,
    gzipMinLength: 1024,
    // Cache
    cacheTtl: const Duration(seconds: 60),
    cacheMaxEntries: 500,
    // HTTPS — uncomment with your certificate:
    // securityContext: SecurityContext()
    //   ..useCertificateChain('cert.pem')
    //   ..usePrivateKey('key.pem'),
  );

  // ─────────────────────────────────────────────────────────────────────
  // 18. Graceful shutdown
  // ─────────────────────────────────────────────────────────────────────
  await server.ready;
  print('Sparky running on http://127.0.0.1:${server.actualPort}');

  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await server.close();
    exit(0);
  });
}

final class ExampleRoute extends Route {
  ExampleRoute() : super('example', middleware: null);
}
