// @author viniciusddrft
//
// Multi-feature integration tests crossing CSRF + RateLimit + Cluster + JWT.
// Each scenario combines at least two of these features to catch interaction
// regressions that the per-feature suites (csrf_test, rate_limiter_test,
// sparky_test) cannot see in isolation.

import 'dart:convert';
import 'dart:io';

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

const _kClusterJwtSecret = 'integration-secret-key';
const _kClusterPort = 4710;

Future<Response?> _bearerJwtGuard(
  SparkyRequest request,
  AuthJwt jwt,
) async {
  final auth = request.headers.value('Authorization');
  if (auth == null || !auth.toLowerCase().startsWith('bearer ')) {
    return const Response.unauthorized(body: {'error': 'missing-bearer'});
  }
  if (!jwt.verifyToken(auth.substring(7))) {
    return const Response.unauthorized(body: {'error': 'invalid-token'});
  }
  return null;
}

// Top-level factory: cluster of JWT-protected servers sharing one secret.
Sparky _clusterJwtFactory(int isolateIndex) {
  const jwt = AuthJwt(secretKey: _kClusterJwtSecret);
  return Sparky.single(
    server: const ServerOptions(port: _kClusterPort, shared: true),
    logConfig: LogConfig.none,
    routes: [
      RouteHttp.get(
        '/me',
        middleware: (r) async => Response.ok(body: {'isolate': isolateIndex}),
        guards: [(r) => _bearerJwtGuard(r, jwt)],
      ),
    ],
  );
}

// Top-level factory: each isolate runs its own RateLimiter (no shared state).
Sparky _clusterRateLimitFactory(int isolateIndex) {
  final limiter = RateLimiter(
    maxRequests: 1,
    window: const Duration(minutes: 5),
  );
  return Sparky.single(
    server: const ServerOptions(port: _kClusterPort, shared: true),
    logConfig: LogConfig.none,
    pipelineBefore: Pipeline()..add(limiter.createMiddleware()),
    routes: [
      RouteHttp.get(
        '/ping',
        middleware: (r) async => Response.ok(body: {'isolate': isolateIndex}),
      ),
    ],
  );
}

String? _csrfCookie(List<Cookie> cookies) {
  for (final c in cookies) {
    if (c.name == 'sparky_csrf') return c.value;
  }
  return null;
}

void main() {
  // ── Scenario 1: CSRF + JWT ────────────────────────────────────────────
  group('CSRF + JWT', () {
    late SparkyTestClient client;
    const jwt = AuthJwt(secretKey: 'csrf-jwt-secret');

    setUp(() async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/api/data',
            middleware: (r) async => const Response.ok(body: {'ok': true}),
            guards: [(r) => _bearerJwtGuard(r, jwt)],
          ),
        ],
        pipelineBefore: Pipeline()..add(const CsrfConfig().createMiddleware()),
      );
    });

    tearDown(() => client.close());

    test(
      'CSRF blocks POST without bearer; valid bearer skips CSRF and the JWT '
      'guard accepts; bogus bearer skips CSRF but JWT guard rejects',
      () async {
        // (a) No Authorization, no CSRF cookie → CSRF rejects.
        final blocked = await client.post('/api/data', body: {'x': 1});
        expect(blocked.statusCode, HttpStatus.forbidden);
        expect((blocked.jsonBody as Map)['error'], 'csrf_validation_failed');

        // (b) Valid Bearer JWT → CSRF skipped, JWT guard accepts.
        final goodToken = jwt.generateToken({'sub': 'alice'});
        final ok = await client.post(
          '/api/data',
          body: {'x': 1},
          headers: {'Authorization': 'Bearer $goodToken'},
        );
        expect(ok.statusCode, HttpStatus.ok);
        expect((ok.jsonBody as Map)['ok'], true);

        // (c) Bearer present but bogus → CSRF still skipped, JWT guard rejects.
        final bad = await client.post(
          '/api/data',
          body: {'x': 1},
          headers: {'Authorization': 'Bearer not-a-real-jwt'},
        );
        expect(bad.statusCode, HttpStatus.unauthorized);
        expect((bad.jsonBody as Map)['error'], 'invalid-token');
      },
    );
  });

  // ── Scenario 2: CSRF + RateLimit ──────────────────────────────────────
  group('CSRF + RateLimit', () {
    late SparkyTestClient client;

    setUp(() async {
      final limiter = RateLimiter(
        maxRequests: 3,
        window: const Duration(minutes: 5),
      );
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/',
            middleware: (r) async => const Response.ok(body: 'home'),
          ),
        ],
        pipelineBefore: Pipeline()
          ..add(limiter.createMiddleware())
          ..add(const CsrfConfig().createMiddleware()),
      );
    });

    tearDown(() => client.close());

    test(
      'rate limit triggers on a CSRF-protected route; only requests that '
      'pass the limiter receive a CSRF cookie',
      () async {
        var ok = 0;
        var tooMany = 0;
        var csrfCookieCount = 0;

        for (var i = 0; i < 4; i++) {
          final res = await client.get('/');
          if (res.statusCode == HttpStatus.ok) {
            ok++;
            if (_csrfCookie(res.cookies) != null) csrfCookieCount++;
          } else if (res.statusCode == HttpStatus.tooManyRequests) {
            tooMany++;
          }
        }

        expect(ok, 3, reason: 'first 3 requests pass the limiter');
        expect(tooMany, 1, reason: '4th request is throttled');
        expect(csrfCookieCount, 3,
            reason: 'CSRF middleware runs only after the limiter passes — '
                'throttled requests must not get a token cookie');
      },
    );
  });

  // ── Scenario 3: RateLimit + JWT ───────────────────────────────────────
  group('RateLimit + JWT', () {
    late SparkyTestClient client;
    const jwt = AuthJwt(secretKey: 'ratelimit-jwt-secret');

    setUp(() async {
      final limiter = RateLimiter(
        maxRequests: 2,
        window: const Duration(minutes: 5),
      );
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/me',
            middleware: (r) async => const Response.ok(body: {'me': 'ok'}),
            guards: [(r) => _bearerJwtGuard(r, jwt)],
          ),
        ],
        pipelineBefore: Pipeline()..add(limiter.createMiddleware()),
      );
    });

    tearDown(() => client.close());

    test('valid auth does not bypass rate limit', () async {
      final token = jwt.generateToken({'sub': 'bob'});
      final headers = {'Authorization': 'Bearer $token'};

      final first = await client.get('/me', headers: headers);
      final second = await client.get('/me', headers: headers);
      final third = await client.get('/me', headers: headers);

      expect(first.statusCode, HttpStatus.ok);
      expect(second.statusCode, HttpStatus.ok);
      expect(third.statusCode, HttpStatus.tooManyRequests);
      expect(third.headers.value('Retry-After'), isNotNull);
    });
  });

  // ── Scenario 4: CSRF + RateLimit + JWT (full pipeline) ────────────────
  group('CSRF + RateLimit + JWT', () {
    late SparkyTestClient client;
    const jwt = AuthJwt(secretKey: 'full-pipeline-secret');

    setUp(() async {
      final limiter = RateLimiter(
        maxRequests: 3,
        window: const Duration(minutes: 5),
      );
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.post(
            '/tx',
            middleware: (r) async => const Response.ok(body: {'tx': 'done'}),
            guards: [(r) => _bearerJwtGuard(r, jwt)],
          ),
        ],
        pipelineBefore: Pipeline()
          ..add(limiter.createMiddleware())
          ..add(const CsrfConfig().createMiddleware()),
      );
    });

    tearDown(() => client.close());

    test(
      'with CSRF + RateLimit + JWT all wired: valid Bearer requests succeed '
      'until the limit is exhausted, then the limiter throttles before CSRF '
      'and JWT get a chance to evaluate',
      () async {
        final token = jwt.generateToken({'sub': 'carol'});
        final headers = {'Authorization': 'Bearer $token'};

        for (var i = 0; i < 3; i++) {
          final res = await client.post('/tx', body: {}, headers: headers);
          expect(res.statusCode, HttpStatus.ok,
              reason: 'request #${i + 1} passes limiter, CSRF (Bearer skip), '
                  'and JWT guard');
        }

        final fourth = await client.post('/tx', body: {}, headers: headers);
        expect(fourth.statusCode, HttpStatus.tooManyRequests,
            reason: 'limiter is added before CSRF/JWT in the pipeline');
      },
    );
  });

  // ── Scenario 5: Cluster + JWT ─────────────────────────────────────────
  group('Cluster + JWT', () {
    test(
      'a JWT signed with the shared secret verifies on any isolate; '
      'requests without a token are rejected on every isolate',
      () async {
        final cluster = await Sparky.cluster(_clusterJwtFactory, isolates: 2);
        try {
          const jwt = AuthJwt(secretKey: _kClusterJwtSecret);
          final token = jwt.generateToken({'sub': 'dave'});

          final isolatesSeen = <int>{};
          for (var i = 0; i < 6; i++) {
            // Fresh HttpClient per request → new TCP connection so SO_REUSEPORT
            // can route different requests to different isolates.
            final c = HttpClient();
            final req = await c.get('localhost', cluster.port, '/me');
            req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
            final res = await req.close();
            expect(res.statusCode, HttpStatus.ok,
                reason: 'request #$i should validate the shared-secret JWT');
            final body =
                json.decode(await utf8.decoder.bind(res).join()) as Map;
            isolatesSeen.add(body['isolate'] as int);
            c.close(force: true);
          }

          // Without Bearer: rejected by every isolate.
          for (var i = 0; i < 3; i++) {
            final c = HttpClient();
            final req = await c.get('localhost', cluster.port, '/me');
            final res = await req.close();
            expect(res.statusCode, HttpStatus.unauthorized);
            await res.drain<void>();
            c.close(force: true);
          }

          expect(isolatesSeen, isNotEmpty,
              reason: 'at least one isolate must have served traffic');
        } finally {
          await cluster.close();
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ── Scenario 6: Cluster + RateLimit ───────────────────────────────────
  group('Cluster + RateLimit', () {
    test(
      'RateLimiter state is per-isolate: with N isolates and maxRequests=1, '
      'a single client succeeds at most N times before being throttled',
      () async {
        const isolates = 2;
        final cluster = await Sparky.cluster(
          _clusterRateLimitFactory,
          isolates: isolates,
        );
        try {
          var ok = 0;
          var tooMany = 0;
          const total = 8;
          for (var i = 0; i < total; i++) {
            final c = HttpClient();
            final req = await c.get('localhost', cluster.port, '/ping');
            final res = await req.close();
            if (res.statusCode == HttpStatus.ok) {
              ok++;
            } else if (res.statusCode == HttpStatus.tooManyRequests) {
              tooMany++;
            }
            await res.drain<void>();
            c.close(force: true);
          }

          expect(ok, lessThanOrEqualTo(isolates),
              reason: 'limiter state lives in the isolate, not globally — '
                  'a single client cannot exceed maxRequests*isolates');
          expect(ok, greaterThanOrEqualTo(1),
              reason: 'at least one request should pass the limiter');
          expect(tooMany, greaterThanOrEqualTo(total - isolates),
              reason: 'the rest should be throttled');
          expect(ok + tooMany, total,
              reason: 'every request must be either 200 or 429');
        } finally {
          await cluster.close();
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
