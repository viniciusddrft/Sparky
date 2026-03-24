// @author viniciusddrft
//
// Complete example showcasing all Sparky features.
// Run: dart run example/sparky_example.dart

import 'dart:io';
import 'dart:math';
import 'package:sparky/sparky.dart';

void main() async {
  // ── JWT Authentication ──────────────────────────────────────────────
  const authJwt = AuthJwt(secretKey: 'my-super-secret-key');

  // Auth guard reusable across routes and groups
  Future<Response?> authGuard(HttpRequest request) async {
    final token = request.headers.value('Authorization');
    if (token != null && authJwt.verifyToken(token)) {
      final payload = authJwt.decodePayload(token);
      print('Authenticated user: ${payload?['username']}');
      return null;
    }
    return const Response.unauthorized(
      body: {'error': 'Missing or invalid token'},
    );
  }

  // ── Public routes (no auth) ─────────────────────────────────────────
  final login = RouteHttp.post('/login', middleware: (request) async {
    final data = await request.getJsonBody();
    final token = authJwt.generateToken(
      {'username': data['user'] ?? '', 'role': data['role'] ?? 'user'},
      expiresIn: const Duration(hours: 2),
    );
    return Response.ok(body: {'token': token});
  });

  final healthCheck = RouteHttp.get('/health',
      middleware: (r) async => const Response.ok(body: {'status': 'ok'}));

  // ── Request body validation ─────────────────────────────────────────
  final registerSchema = Validator({
    'name': [isRequired, isString, minLength(3), maxLength(50)],
    'email': [isRequired, isString, isEmail],
    'age': [isRequired, isNum, min(18)],
    'role': [isString, oneOf(['admin', 'user', 'editor'])],
  });

  final register = RouteHttp.post('/register', middleware: (request) async {
    final body = await request.getJsonBody();
    final errors = registerSchema.validate(body);
    if (errors.isNotEmpty) {
      return Response.badRequest(body: {'errors': errors});
    }
    return Response.created(body: {'ok': true, 'user': body['name']});
  });

  // ── Dynamic routes with path parameters ─────────────────────────────
  final userById =
      RouteHttp.get('/users/:id', middleware: (request) async {
    final userId = request.pathParams['id'];
    return Response.ok(body: {'userId': userId, 'name': 'User $userId'});
  });

  final productRoute = RouteHttp.get('/products/:category/:itemId',
      middleware: (request) async {
    return Response.ok(body: {
      'category': request.pathParams['category'],
      'itemId': request.pathParams['itemId'],
    });
  });

  // ── Route with guards ───────────────────────────────────────────────
  final adminOnly = RouteHttp.get('/admin/dashboard',
      middleware: (r) async =>
          const Response.ok(body: {'dashboard': 'admin data'}),
      guards: [authGuard]);

  // ── Route groups with shared guards ─────────────────────────────────
  final apiV1 = RouteGroup('/api/v1', guards: [authGuard], routes: [
    RouteHttp.get('/status',
        middleware: (r) async => const Response.ok(body: {'status': 'ok'})),
    RouteHttp.get('/items',
        middleware: (r) async =>
            const Response.ok(body: {'items': ['a', 'b', 'c']})),
  ]);

  // ── Content negotiation ─────────────────────────────────────────────
  final negotiate = RouteHttp.get('/data', middleware: (request) async {
    final preferred =
        request.preferredType(const ['application/json', 'text/html']);
    if (preferred == 'text/html') {
      return Response.ok(
          body: '<h1>Hello</h1>', contentType: ContentType.html);
    }
    return Response.ok(
        body: {'message': 'hello'}, contentType: ContentType.json);
  });

  // ── Cookies ─────────────────────────────────────────────────────────
  final setCookie = RouteHttp.get('/set-cookie', middleware: (request) async {
    final cookie = Cookie('session', 'abc123')
      ..httpOnly = true
      ..secure = true
      ..path = '/';
    return Response.ok(body: {'ok': true}, cookies: [cookie]);
  });

  final readCookie = RouteHttp.get('/read-cookie', middleware: (request) async {
    final session = request.getCookie('session');
    return Response.ok(body: {'session': session?.value ?? 'none'});
  });

  // ── Random (cache demonstration) ────────────────────────────────────
  final random = RouteHttp.get('/random', middleware: (request) async {
    final value = Random().nextInt(100);
    return Response.ok(body: {'value': value});
  });

  // ── Body parsing ────────────────────────────────────────────────────
  final echo = RouteHttp.post('/echo', middleware: (request) async {
    final body = await request.getJsonBody();
    return Response.ok(body: {'echo': body});
  });

  final formEndpoint = RouteHttp.post('/form', middleware: (request) async {
    final form = await request.getFormData();
    return Response.ok(body: {'received': form});
  });

  // ── WebSocket ───────────────────────────────────────────────────────
  final websocket = RouteWebSocket(
    '/ws',
    middlewareWebSocket: (WebSocket socket) async {
      socket.add('Hello from Sparky!');
      socket.listen(
        (data) {
          socket.add('Echo: $data');
        },
        onDone: () => socket.close(),
      );
    },
  );

  // ── Class-based routes ──────────────────────────────────────────────
  final classRoute = RouteTest();
  final classSocket = RouteSocket();

  // ── CORS configuration ──────────────────────────────────────────────
  const cors = CorsConfig(
    allowOrigins: ['https://myapp.com', 'https://admin.myapp.com'],
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowCredentials: true,
  );

  // ── Rate limiter ────────────────────────────────────────────────────
  final limiter = RateLimiter(
    maxRequests: 100,
    window: const Duration(minutes: 5),
  );

  // ── Static files ────────────────────────────────────────────────────
  const staticFiles = StaticFiles(
    urlPath: '/public',
    directory: './static',
    maxFileSize: 5 * 1024 * 1024, // 5 MB
  );

  // ── Server setup ────────────────────────────────────────────────────
  final server = Sparky.server(
    routes: [
      // Public routes
      login,
      register,
      healthCheck,
      // Dynamic routes
      userById,
      productRoute,
      // Guarded route
      adminOnly,
      // Content negotiation & cookies
      negotiate,
      setCookie,
      readCookie,
      // Cache demo
      random,
      // Body parsing
      echo,
      formEndpoint,
      // WebSocket
      websocket,
      // Class-based
      classRoute,
      classSocket,
      // Grouped routes (flatten expands to /api/v1/status, /api/v1/items)
      ...apiV1.flatten(),
    ],
    port: 3000,
    ip: '127.0.0.1',
    // Logging
    logConfig: LogConfig.showLogs,
    logType: LogType.errors,
    logFilePath: 'server.log',
    // Security
    maxBodySize: 10 * 1024 * 1024, // 10 MB
    requestTimeout: const Duration(seconds: 30),
    // Performance
    enableGzip: true,
    gzipMinLength: 1024, // only gzip responses >= 1 KB
    // Cache
    cacheTtl: const Duration(seconds: 60),
    cacheMaxEntries: 500,
    // Pipelines
    pipelineBefore: Pipeline()
      ..add(cors.createMiddleware())
      ..add(limiter.createMiddleware())
      ..add(staticFiles.createMiddleware())
      ..add((request) async {
        // Invalidate cache for /random on every request
        if (request.uri.path == random.name) {
          random.onUpdate();
        }
        return null;
      }),
    pipelineAfter: Pipeline()
      ..add((request) async {
        print('Request completed: ${request.method} ${request.uri.path}');
        return null;
      }),
    // Uncomment for HTTPS:
    // securityContext: SecurityContext()
    //   ..useCertificateChain('cert.pem')
    //   ..usePrivateKey('key.pem'),
  );

  await server.ready;
  print('Sparky running on http://127.0.0.1:${server.actualPort}');
  print('Press Ctrl+C to stop.');

  // Graceful shutdown on SIGINT
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await server.close();
    exit(0);
  });
}

// ── Class-based route examples ──────────────────────────────────────────

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
