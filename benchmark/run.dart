// Author: viniciusddrft
//
// Benchmark orchestrator. Runs all scenarios and prints a markdown table.
//
// Usage:
//   dart run benchmark/run.dart          # full (~25s)
//   dart run benchmark/run.dart --smoke  # fast sanity check (~10s) — CI

import 'dart:io';

import '_harness.dart';
import 'dynamic_routing_bench.dart' as dynamic_routing;
import 'json_body_bench.dart' as json_body;
import 'multipart_bench.dart' as multipart;
import 'plain_text_bench.dart' as plain_text;
import 'static_routing_bench.dart' as static_routing;

Future<void> main(List<String> args) async {
  final smoke = args.contains('--smoke');
  final config = BenchConfig(smoke: smoke);

  stdout.writeln('Sparky benchmarks (${smoke ? "smoke" : "full"})');
  stdout.writeln('Dart ${Platform.version.split(" ").first} on '
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  stdout.writeln();

  final results = <BenchResult>[];

  results.addAll(await static_routing.run(config));
  results.addAll(await dynamic_routing.run(config));
  results.addAll(await json_body.run(config));
  results.addAll(await plain_text.run(config));
  results.addAll(await multipart.run(config));

  stdout.writeln();
  stdout.writeln(formatTable(results));
}
