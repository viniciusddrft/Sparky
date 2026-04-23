// Author: viniciusddrft
//
// Shared benchmark harness for Sparky.
//
// Wraps `package:benchmark_harness` so a single `--smoke` flag can switch
// between a fast sanity check (CI) and the longer measurement used to
// produce the numbers in the README.

import 'package:benchmark_harness/benchmark_harness.dart';

/// Knobs that affect iteration counts. `smoke` mode is only meant to verify
/// the benchmark still compiles and runs end-to-end.
final class BenchConfig {
  final bool smoke;
  const BenchConfig({required this.smoke});

  /// Warmup duration passed to `measureFor`.
  int get warmupMs => smoke ? 30 : 100;

  /// Measurement duration passed to `measureFor`.
  int get measureMs => smoke ? 150 : 2000;
}

final class BenchResult {
  final String name;
  final double usPerOp;
  const BenchResult(this.name, this.usPerOp);

  double get opsPerSec => usPerOp <= 0 ? 0 : 1e6 / usPerOp;
}

/// Runs an [AsyncBenchmarkBase] with durations taken from [config] instead of
/// the library defaults (100ms warmup + 2000ms exercise).
Future<BenchResult> runAsyncBench(
  AsyncBenchmarkBase bench,
  BenchConfig config,
) async {
  await bench.setup();
  try {
    await AsyncBenchmarkBase.measureFor(bench.warmup, config.warmupMs);
    final us =
        await AsyncBenchmarkBase.measureFor(bench.exercise, config.measureMs);
    return BenchResult(bench.name, us);
  } finally {
    await bench.teardown();
  }
}

/// Sync variant. Uses `BenchmarkBase.measureFor`.
BenchResult runSyncBench(BenchmarkBase bench, BenchConfig config) {
  bench.setup();
  try {
    BenchmarkBase.measureFor(bench.warmup, config.warmupMs);
    final us = BenchmarkBase.measureFor(bench.exercise, config.measureMs);
    return BenchResult(bench.name, us);
  } finally {
    bench.teardown();
  }
}

/// Formats a list of results as a markdown table.
String formatTable(List<BenchResult> results) {
  final buf = StringBuffer()
    ..writeln('| Scenario                           |   µs/op |  ops/sec |')
    ..writeln('|------------------------------------|--------:|---------:|');
  for (final r in results) {
    final us = r.usPerOp.toStringAsFixed(2);
    final ops = r.opsPerSec.toStringAsFixed(0);
    buf.writeln(
        '| ${r.name.padRight(34)} | ${us.padLeft(7)} | ${ops.padLeft(8)} |');
  }
  return buf.toString();
}
