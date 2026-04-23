// Author: viniciusddrft
//
// Static route resolution. Measures the hot path that serves a request hitting
// a route registered by exact path (the `_staticHttpRoutes` Map lookup).

import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';

import '_harness.dart';

Future<List<BenchResult>> run(BenchConfig config) async {
  final results = <BenchResult>[];
  for (final size in const [10, 100, 1000]) {
    final bench = _StaticRoutingBench(size);
    results.add(await runAsyncBench(bench, config));
  }
  return results;
}

final class _StaticRoutingBench extends AsyncBenchmarkBase {
  final int routeCount;
  late SparkyTestClient _client;
  late HttpClient _raw;
  late int _port;
  late List<String> _paths;
  int _cursor = 0;

  _StaticRoutingBench(this.routeCount)
      : super('static routing ($routeCount routes)');

  @override
  Future<void> setup() async {
    final routes = <Route>[
      for (var i = 0; i < routeCount; i++)
        RouteHttp.get('/path/$i',
            middleware: (r) async => const Response.ok(body: 'ok')),
    ];
    _client = await SparkyTestClient.boot(routes: routes);
    _port = _client.port;
    _raw = HttpClient();
    _paths = [for (var i = 0; i < routeCount; i++) '/path/$i'];
  }

  @override
  Future<void> run() async {
    final path = _paths[_cursor++ % _paths.length];
    final req = await _raw.open('GET', 'localhost', _port, path);
    final res = await req.close();
    await res.drain<void>();
  }

  @override
  Future<void> teardown() async {
    _raw.close(force: true);
    await _client.close();
  }
}
