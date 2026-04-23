// @author viniciusddrft

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimiter', () {
    late SparkyTestClient client;

    tearDown(() async {
      await client.close();
    });

    test(
        'ignorePaths bypasses the limiter: 200 requests to /health all return 200 '
        'with maxRequests: 1', () async {
      final limiter = RateLimiter(
        maxRequests: 1,
        ignorePaths:const {
          '/health',
          '/ready',
          '/metrics',
          '/openapi.json',
          '/docs',
        },
      );

      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/x',
            middleware: (_) async => const Response.ok(body: 'ok'),
          ),
        ],
        health: const HealthCheckConfig(),
        pipelineBefore: Pipeline()..add(limiter.createMiddleware()),
      );

      for (var i = 0; i < 200; i++) {
        final res = await client.get('/health');
        expect(
          res.statusCode,
          200,
          reason: 'request #$i to /health should bypass the rate limiter',
        );
      }
    });

    test('non-ignored paths still get rate limited', () async {
      final limiter = RateLimiter(
        maxRequests: 1,
        ignorePaths:const {'/health'},
      );

      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/x',
            middleware: (_) async => const Response.ok(body: 'ok'),
          ),
        ],
        pipelineBefore: Pipeline()..add(limiter.createMiddleware()),
      );

      final first = await client.get('/x');
      expect(first.statusCode, 200);

      final second = await client.get('/x');
      expect(second.statusCode, 429);
    });
  });
}
