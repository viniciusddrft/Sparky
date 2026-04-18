// @author viniciusddrft

import 'dart:async';
import 'dart:io';

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  group('HealthCheckConfig', () {
    late SparkyTestClient client;

    tearDown(() async {
      await client.close();
    });

    test('GET /health returns 200 with status UP when no checks', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: const HealthCheckConfig(),
      );

      final res = await client.get('/health');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, Object?>;
      expect(body['status'], 'UP');
      expect(body.containsKey('checks'), isFalse);
    });

    test('GET /ready aggregates checks and returns 200 when all UP', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: HealthCheckConfig(
          readinessChecks: {
            'db': () => const HealthCheckResult.up(),
            'cache': () => const HealthCheckResult.up(details: {'latencyMs': 2}),
          },
        ),
      );

      final res = await client.get('/ready');
      expect(res.statusCode, 200);
      final body = res.jsonBody as Map<String, Object?>;
      expect(body['status'], 'UP');
      final checks = body['checks'] as Map<String, Object?>;
      expect(checks['db'], {'status': 'UP'});
      final cache = checks['cache'] as Map<String, Object?>;
      expect(cache['status'], 'UP');
      expect(cache['details'], {'latencyMs': 2});
    });

    test('GET /ready returns 503 when any check is DOWN', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: HealthCheckConfig(
          readinessChecks: {
            'db': () => const HealthCheckResult.up(),
            'redis': () =>
                const HealthCheckResult.down(message: 'connection refused'),
          },
        ),
      );

      final res = await client.get('/ready');
      expect(res.statusCode, HttpStatus.serviceUnavailable);
      final body = res.jsonBody as Map<String, Object?>;
      expect(body['status'], 'DOWN');
      final redis = (body['checks'] as Map)['redis'] as Map<String, Object?>;
      expect(redis['status'], 'DOWN');
      expect(redis['message'], 'connection refused');
    });

    test('GET /ready with DEGRADED returns 200 by default', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: HealthCheckConfig(
          readinessChecks: {
            'slow': () =>
                const HealthCheckResult.degraded(message: 'p99 too high'),
          },
        ),
      );

      final res = await client.get('/ready');
      expect(res.statusCode, 200);
      expect((res.jsonBody as Map)['status'], 'DEGRADED');
    });

    test('failReadinessOnDegraded flips DEGRADED to 503', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: HealthCheckConfig(
          failReadinessOnDegraded: true,
          readinessChecks: {
            'slow': () => const HealthCheckResult.degraded(),
          },
        ),
      );

      final res = await client.get('/ready');
      expect(res.statusCode, HttpStatus.serviceUnavailable);
      expect((res.jsonBody as Map)['status'], 'DEGRADED');
    });

    test('thrown exception is reported as DOWN with message', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: HealthCheckConfig(
          readinessChecks: {
            'broken': () => throw StateError('boom'),
          },
        ),
      );

      final res = await client.get('/ready');
      expect(res.statusCode, HttpStatus.serviceUnavailable);
      final broken = ((res.jsonBody as Map)['checks'] as Map)['broken']
          as Map<String, Object?>;
      expect(broken['status'], 'DOWN');
      expect(broken['message'], contains('boom'));
    });

    test('check timeout reports DOWN with timeout message', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: HealthCheckConfig(
          checkTimeout: const Duration(milliseconds: 50),
          readinessChecks: {
            'hang': () async {
              await Future.delayed(const Duration(seconds: 2));
              return const HealthCheckResult.up();
            },
          },
        ),
      );

      final res = await client.get('/ready');
      expect(res.statusCode, HttpStatus.serviceUnavailable);
      final hang =
          ((res.jsonBody as Map)['checks'] as Map)['hang'] as Map<String, Object?>;
      expect(hang['status'], 'DOWN');
      expect(hang['message'], 'timeout');
    });

    test('authGuard blocks unauthenticated /ready', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: HealthCheckConfig(
          authGuard: (request) async {
            if (request.headers.value('X-Probe-Token') != 'secret') {
              return const Response.unauthorized(body: 'no');
            }
            return null;
          },
          readinessChecks: {
            'db': () => const HealthCheckResult.up(),
          },
        ),
      );

      final blocked = await client.get('/ready');
      expect(blocked.statusCode, HttpStatus.unauthorized);

      final allowed =
          await client.get('/ready', headers: {'X-Probe-Token': 'secret'});
      expect(allowed.statusCode, 200);
    });

    test('custom paths register correctly', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: const HealthCheckConfig(
          livenessPath: '/alive',
          readinessPath: '/traffic',
        ),
      );

      final live = await client.get('/alive');
      final ready = await client.get('/traffic');
      expect(live.statusCode, 200);
      expect(ready.statusCode, 200);

      final defaults = await client.get('/health');
      expect(defaults.statusCode, HttpStatus.notFound);
    });

    test('disabled HealthCheckConfig does not register routes', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        health: const HealthCheckConfig(enabled: false),
      );

      final res = await client.get('/health');
      expect(res.statusCode, HttpStatus.notFound);
    });

    test('aggregateHealthStatus is worst-case', () {
      expect(aggregateHealthStatus([]), HealthStatus.up);
      expect(
        aggregateHealthStatus([HealthStatus.up, HealthStatus.up]),
        HealthStatus.up,
      );
      expect(
        aggregateHealthStatus([HealthStatus.up, HealthStatus.degraded]),
        HealthStatus.degraded,
      );
      expect(
        aggregateHealthStatus([HealthStatus.degraded, HealthStatus.down]),
        HealthStatus.down,
      );
    });
  });
}
