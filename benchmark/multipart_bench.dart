// Author: viniciusddrft
//
// Multipart benchmarks. Two sub-scenarios:
//  - parser-only: `MultipartParser.parse` on an in-memory synthetic payload
//    with 1× 1 MB file + 2 text fields. Measures the byte-level scanner.
//  - roundtrip: POST multipart to a handler that calls `request.body.multipart()`.
//    Measures parser + HTTP + stream cost.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';

import '_harness.dart';

const _boundary = '----SparkyBenchBoundary0xCAFE';
const _fileSize = 1024 * 1024; // 1 MB

Future<List<BenchResult>> run(BenchConfig config) async {
  final payload = _buildMultipartPayload();
  final results = <BenchResult>[];

  final parser = _MultipartParserBench(payload);
  results.add(await runAsyncBench(parser, config));

  final roundtrip = _MultipartRoundtripBench(payload);
  results.add(await runAsyncBench(roundtrip, config));

  return results;
}

final class _MultipartParserBench extends AsyncBenchmarkBase {
  final Uint8List payload;
  _MultipartParserBench(this.payload) : super('multipart parser (1 MB file)');

  @override
  Future<void> run() async {
    final parser =
        MultipartParser(Stream<List<int>>.value(payload), _boundary);
    final data = await parser.parse();
    if (data.files.length != 1) {
      throw StateError('parser lost the file');
    }
  }
}

final class _MultipartRoundtripBench extends AsyncBenchmarkBase {
  final Uint8List payload;
  late SparkyTestClient _client;
  late HttpClient _raw;
  late int _port;

  _MultipartRoundtripBench(this.payload)
      : super('multipart roundtrip (1 MB file)');

  @override
  Future<void> setup() async {
    _client = await SparkyTestClient.boot(
      routes: [
        RouteHttp.post('/upload', middleware: (r) async {
          final form = await r.body.multipart();
          return Response.ok(body: {'files': form.files.length});
        }),
      ],
      limits: const LimitsConfig(maxBodySize: 4 * 1024 * 1024),
    );
    _port = _client.port;
    _raw = HttpClient();
  }

  @override
  Future<void> run() async {
    final req = await _raw.open('POST', 'localhost', _port, '/upload');
    req.headers.contentType =
        ContentType('multipart', 'form-data', parameters: {'boundary': _boundary});
    req.contentLength = payload.length;
    req.add(payload);
    final res = await req.close();
    await res.drain<void>();
  }

  @override
  Future<void> teardown() async {
    _raw.close(force: true);
    await _client.close();
  }
}

Uint8List _buildMultipartPayload() {
  final buf = BytesBuilder(copy: false);
  void writeLine(String s) {
    buf.add(utf8.encode(s));
    buf.add(const [13, 10]); // \r\n
  }

  // Field 1
  writeLine('--$_boundary');
  writeLine('Content-Disposition: form-data; name="title"');
  writeLine('');
  writeLine('benchmark upload');

  // Field 2
  writeLine('--$_boundary');
  writeLine('Content-Disposition: form-data; name="tag"');
  writeLine('');
  writeLine('perf');

  // File
  writeLine('--$_boundary');
  writeLine(
      'Content-Disposition: form-data; name="blob"; filename="blob.bin"');
  writeLine('Content-Type: application/octet-stream');
  writeLine('');
  buf.add(Uint8List(_fileSize)); // 1 MB of zeros
  buf.add(const [13, 10]);

  // Closing boundary
  buf.add(utf8.encode('--$_boundary--\r\n'));

  return buf.takeBytes();
}
