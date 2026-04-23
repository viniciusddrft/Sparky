// Author: viniciusddrft
//
// Dynamic route resolution. Measures the linear scan through `_dynamicRoutes`
// calling `matchPath` until one matches. This is the baseline the radix-tree
// decision in PLAN.md depends on.

import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';

import '_harness.dart';

Future<List<BenchResult>> run(BenchConfig config) async {
  final bench = _DynamicRoutingBench();
  return [await runAsyncBench(bench, config)];
}

final class _DynamicRoutingBench extends AsyncBenchmarkBase {
  late SparkyTestClient _client;
  late HttpClient _raw;
  late int _port;
  late List<String> _requestPaths;
  int _cursor = 0;

  _DynamicRoutingBench() : super('dynamic routing (50 routes, :param)');

  @override
  Future<void> setup() async {
    // Mix of one-segment and two-segment dynamic routes to exercise the
    // pattern compiler and ensure the match isn't trivially the first entry.
    final routes = <Route>[
      for (var i = 0; i < 40; i++)
        RouteHttp.get('/resource$i/:id',
            middleware: (r) async => const Response.ok(body: 'ok')),
      for (var i = 0; i < 10; i++)
        RouteHttp.get('/orgs/:oid/widgets$i/:wid',
            middleware: (r) async => const Response.ok(body: 'ok')),
    ];
    _client = await SparkyTestClient.boot(routes: routes);
    _port = _client.port;
    _raw = HttpClient();

    // Target paths that land across the full route list to avoid measuring
    // only the fast first-hit case.
    _requestPaths = [
      for (var i = 0; i < 40; i++) '/resource$i/${i * 7}',
      for (var i = 0; i < 10; i++) '/orgs/org_$i/widgets$i/${i * 13}',
    ];
  }

  @override
  Future<void> run() async {
    final path = _requestPaths[_cursor++ % _requestPaths.length];
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
