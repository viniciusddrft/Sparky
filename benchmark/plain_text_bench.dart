// Author: viniciusddrft
//
// Plain-text response. Measures the framework's fixed per-request cost with a
// tiny body, isolated from routing complexity and body parsing.

import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';

import '_harness.dart';

Future<List<BenchResult>> run(BenchConfig config) async {
  final bench = _PlainTextBench();
  return [await runAsyncBench(bench, config)];
}

final class _PlainTextBench extends AsyncBenchmarkBase {
  late SparkyTestClient _client;
  late HttpClient _raw;
  late int _port;

  _PlainTextBench() : super('plain text response');

  @override
  Future<void> setup() async {
    _client = await SparkyTestClient.boot(
      routes: [
        RouteHttp.get('/hello',
            middleware: (r) async => const Response.ok(body: 'hello')),
      ],
    );
    _port = _client.port;
    _raw = HttpClient();
  }

  @override
  Future<void> run() async {
    final req = await _raw.open('GET', 'localhost', _port, '/hello');
    final res = await req.close();
    await res.drain<void>();
  }

  @override
  Future<void> teardown() async {
    _raw.close(force: true);
    await _client.close();
  }
}
