// Author: viniciusddrft
//
// JSON body parsing. The handler calls `request.body.json()` on each request,
// exercising the cache-once body read + `dart:convert` decode.

import 'dart:convert';
import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';

import '_harness.dart';

Future<List<BenchResult>> run(BenchConfig config) async {
  final results = <BenchResult>[];
  for (final kb in const [1, 100]) {
    final bench = _JsonBodyBench(kb);
    results.add(await runAsyncBench(bench, config));
  }
  return results;
}

final class _JsonBodyBench extends AsyncBenchmarkBase {
  final int payloadKb;
  late SparkyTestClient _client;
  late HttpClient _raw;
  late int _port;
  late List<int> _payload;

  _JsonBodyBench(this.payloadKb) : super('json body ($payloadKb KB)');

  @override
  Future<void> setup() async {
    _client = await SparkyTestClient.boot(
      routes: [
        RouteHttp.post('/echo', middleware: (r) async {
          final map = await r.body.json();
          return Response.ok(body: {'received': map.length});
        }),
      ],
      // Allow 100KB+ body
      limits: const LimitsConfig(maxBodySize: 1024 * 1024),
    );
    _port = _client.port;
    _raw = HttpClient();
    _payload = utf8.encode(_buildJsonPayload(payloadKb));
  }

  @override
  Future<void> run() async {
    final req = await _raw.open('POST', 'localhost', _port, '/echo');
    req.headers.contentType = ContentType.json;
    req.contentLength = _payload.length;
    req.add(_payload);
    final res = await req.close();
    await res.drain<void>();
  }

  @override
  Future<void> teardown() async {
    _raw.close(force: true);
    await _client.close();
  }
}

/// Builds a JSON object whose UTF-8 encoding is approximately [kb] KB.
String _buildJsonPayload(int kb) {
  final target = kb * 1024;
  // Each entry "k000":"vXXXX..." is ~32 bytes with padding; adjust entry count.
  final map = <String, String>{};
  var i = 0;
  while (true) {
    map['key$i'] = 'value_$i' * 3;
    i++;
    if (json.encode(map).length >= target) break;
  }
  return json.encode(map);
}
