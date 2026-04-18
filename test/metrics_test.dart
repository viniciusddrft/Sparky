// @author viniciusddrft

import 'dart:io';

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  group('PrometheusMetrics', () {
    test('histogram buckets are cumulative per le', () {
      final m = PrometheusMetrics(
        namespace: 'test',
        durationBucketsSeconds: const [0.1, 0.5],
        ignorePaths: const {'/metrics'},
      );
      m.recordHttpRequest(
        method: 'GET',
        path: '/api',
        statusCode: 200,
        elapsed: const Duration(milliseconds: 200),
      );
      final text = m.formatPrometheusText();
      expect(text, contains('test_http_request_duration_seconds_bucket'));
      expect(text, contains('method="GET"'));
      expect(text, contains('test_http_requests_total'));
      expect(text, contains('status="200"'));
    });

    test('ignorePaths skips scrape path and configured paths', () {
      final m = PrometheusMetrics(
        namespace: 'x',
        durationBucketsSeconds: const [1],
        ignorePaths: const {'/metrics', '/ping'},
      );
      m.recordHttpRequest(
        method: 'GET',
        path: '/metrics',
        statusCode: 200,
        elapsed: Duration.zero,
      );
      m.recordHttpRequest(
        method: 'GET',
        path: '/ping',
        statusCode: 200,
        elapsed: Duration.zero,
      );
      expect(m.formatPrometheusText(), isNot(contains('status="200"')));
      m.reset();
    });
  });

  group('MetricsConfig HTTP', () {
    late SparkyTestClient client;

    tearDown(() async {
      await client.close();
    });

    test('GET /metrics returns Prometheus text', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/hello',
            middleware: (r) async => const Response.ok(body: 'ok'),
          ),
        ],
        metrics:  MetricsConfig(),
      );

      final hello = await client.get('/hello');
      expect(hello.statusCode, 200);

      final m = await client.get('/metrics');
      expect(m.statusCode, 200);
      expect(m.body, contains('sparky_http_requests_total'));
      expect(m.body, contains('sparky_http_requests_in_progress'));
      expect(m.body, contains('method="GET"'));
      expect(m.body, contains('sparky_http_request_duration_seconds'));
      expect(m.contentType?.mimeType, 'text/plain');
    });

    test('disabled MetricsConfig omits route', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/x',
            middleware: (r) async => const Response.ok(body: ''),
          ),
        ],
        metrics:  MetricsConfig(enabled: false),
      );

      final m = await client.get('/metrics');
      expect(m.statusCode, HttpStatus.notFound);
    });

    test('authGuard blocks unauthenticated scrape', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/x',
            middleware: (r) async => const Response.ok(body: ''),
          ),
        ],
        metrics: MetricsConfig(
          authGuard: (request) async {
            if (request.headers.value('X-Prom-Token') != 'secret') {
              return const Response.unauthorized(body: 'forbidden');
            }
            return null;
          },
        ),
      );

      final blocked = await client.get('/metrics');
      expect(blocked.statusCode, HttpStatus.unauthorized);

      final allowed =
          await client.get('/metrics', headers: {'X-Prom-Token': 'secret'});
      expect(allowed.statusCode, 200);
      expect(allowed.body, contains('sparky_http_requests_total'));
    });

    test('custom metrics path', () async {
      client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get(
            '/x',
            middleware: (r) async => const Response.ok(body: ''),
          ),
        ],
        metrics:  MetricsConfig(path: '/prom'),
      );

      final res = await client.get('/prom');
      expect(res.statusCode, 200);
      expect(res.body, contains('sparky_http_requests_total'));
    });
  });
}
