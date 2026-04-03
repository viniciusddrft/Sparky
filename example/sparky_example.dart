// @author viniciusddrft

// Sparky — Full Example
//
// Each section below demonstrates one feature independently,
// following the same order as the README.
// Run: dart run example/sparky_example.dart

import 'package:sparky/sparky.dart';
import 'dart:async';
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
  // 17. Multipart upload (binary-safe file upload)
  // ─────────────────────────────────────────────────────────────────────
  final upload = RouteHttp.post('/upload', middleware: (request) async {
    final form = await request.getMultipartData();
    final description = form.fields['description'] ?? 'no description';
    final files = form.fileList
        .map((f) => {
              'name': f.filename,
              'size': f.size,
              'contentType': f.contentType,
            })
        .toList();
    return Response.ok(body: {
      'description': description,
      'filesReceived': files.length,
      'files': files,
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 18. SSE — Server-Sent Events
  // ─────────────────────────────────────────────────────────────────────
  final sse = RouteHttp.get('/events', middleware: (request) async {
    final events = Stream.periodic(
      const Duration(seconds: 1),
      (i) => SseEvent(data: 'tick ${i + 1}', id: '${i + 1}', event: 'tick'),
    ).take(5);
    return Response.sse(events);
  });

  // ─────────────────────────────────────────────────────────────────────
  // 19. Structured error handling (typed HTTP exceptions)
  // ─────────────────────────────────────────────────────────────────────
  final itemRoute = RouteHttp.get('/items/:id', middleware: (request) async {
    final id = request.pathParams['id'];
    switch (id) {
      case '0':
        throw NotFound(message: 'Item not found', details: {'id': id!});
      case '-1':
        throw const Forbidden(message: 'Access denied to this item');
      case 'x':
        throw const BadRequest(message: 'Invalid item ID format');
      default:
        return Response.ok(body: {'id': id, 'name': 'Item $id'});
    }
  });

  // ─────────────────────────────────────────────────────────────────────
  // 20. Dependency injection per request
  // ─────────────────────────────────────────────────────────────────────
  Future<Response?> diGuard(HttpRequest request) async {
    final token = request.headers.value('Authorization');
    if (token == null || !authJwt.verifyToken(token)) {
      return const Response.unauthorized(body: {'error': 'Unauthorized'});
    }
    // Inject an AppUser into the request — available downstream
    request.provide<AppUser>(const AppUser(name: 'Vinicius', role: 'admin'));
    return null;
  }

  final profile = RouteHttp.get('/profile', middleware: (request) async {
    final user = request.read<AppUser>();
    final maybeConfig = request.tryRead<String>(); // null — not provided
    return Response.ok(body: {
      'name': user.name,
      'role': user.role,
      'hasConfig': maybeConfig != null,
    });
  }, guards: [diGuard]);

  // ─────────────────────────────────────────────────────────────────────
  // 21. Security headers (Helmet-style)
  // ─────────────────────────────────────────────────────────────────────
  const securityHeaders = SecurityHeadersConfig();

  // ─────────────────────────────────────────────────────────────────────
  // 22. Start the server with all features
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
      upload,
      sse,
      itemRoute,
      profile,
      ...apiRoutes.flatten(),
    ],
    port: 3000,
    // Pipelines — CORS, rate limit, security headers, static files
    pipelineBefore: Pipeline()
      ..add(cors.createMiddleware())
      ..add(limiter.createMiddleware())
      ..add(securityHeaders.createMiddleware())
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
  // 23. Graceful shutdown
  // ─────────────────────────────────────────────────────────────────────
  await server.ready;
  print('Sparky running on http://127.0.0.1:${server.actualPort}');

  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await server.close();
    exit(0);
  });

  // ─────────────────────────────────────────────────────────────────────
  // NOTE: Isolates / cluster mode
  // ─────────────────────────────────────────────────────────────────────
  // To scale across CPU cores, use Sparky.cluster with a top-level factory:
  //
  //   Sparky createServer(int isolateIndex) {
  //     return Sparky.single(port: 3000, shared: true, routes: [...]);
  //   }
  //
  //   void main() async {
  //     final cluster = await Sparky.cluster(createServer, isolates: 4);
  //     print('Running on ${cluster.port} with 4 isolates');
  //     // cluster.close() to shutdown all isolates
  //   }
}

// ─── Helper class for DI demo ────────────────────────────────────────
final class AppUser {
  final String name;
  final String role;
  const AppUser({required this.name, required this.role});
}

final class ExampleRoute extends Route {
  ExampleRoute() : super('example', middleware: null);
}
