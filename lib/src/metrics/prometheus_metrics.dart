// @author viniciusddrft

/// In-process [Prometheus text format 0.0.4](https://github.com/prometheus/docs/blob/main/content/docs/instrumenting/exposition_formats.md) metrics for Sparky.
///
/// Not thread-safe across isolates: each [Sparky] instance has its own collector.
/// In [Sparky.cluster], each isolate exposes separate series (typical for Prometheus).
final class PrometheusMetrics {
  PrometheusMetrics({
    required this.namespace,
    required List<double> durationBucketsSeconds,
    required Set<String> ignorePaths,
  })  : _ignorePaths = ignorePaths,
        _sortedBuckets = List<double>.from(durationBucketsSeconds)..sort() {
    for (var i = 1; i < _sortedBuckets.length; i++) {
      if (_sortedBuckets[i - 1] >= _sortedBuckets[i]) {
        throw ArgumentError(
          'durationBucketsSeconds must be strictly increasing',
        );
      }
    }
  }

  final String namespace;
  final Set<String> _ignorePaths;
  final List<double> _sortedBuckets;

  int _inFlight = 0;
  final Map<String, int> _requestsTotal = {};
  final Map<String, _HistAgg> _histogram = {};

  /// Call when a request enters the server handler.
  void requestStarted() {
    _inFlight++;
  }

  /// Call once per request in `finally` after recording latency/status.
  void requestFinished() {
    _inFlight--;
  }

  /// Records one completed HTTP exchange (unless [path] is ignored).
  void recordHttpRequest({
    required String method,
    required String path,
    required int statusCode,
    required Duration elapsed,
  }) {
    if (_ignorePaths.contains(path)) return;

    final m = method.toUpperCase();
    final s = statusCode.toString();
    final key = '$m\t$s';
    _requestsTotal[key] = (_requestsTotal[key] ?? 0) + 1;

    final seconds = elapsed.inMicroseconds / 1e6;
    final hist = _histogram.putIfAbsent(m, () => _HistAgg(_sortedBuckets.length));
    hist.count++;
    hist.sum += seconds;
    for (var i = 0; i < _sortedBuckets.length; i++) {
      if (seconds <= _sortedBuckets[i]) {
        hist.bucketCounts[i]++;
      }
    }
    hist.bucketCounts[_sortedBuckets.length]++; // +Inf: all observations
  }

  /// Clears all series (for tests).
  void reset() {
    _inFlight = 0;
    _requestsTotal.clear();
    _histogram.clear();
  }

  String _prefix(String name) {
    final ns = namespace.trim();
    if (ns.isEmpty) return name;
    return '${ns}_$name';
  }

  /// Prometheus text exposition body.
  String formatPrometheusText() {
    final buf = StringBuffer();
    final pTotal = _prefix('http_requests_total');
    final pInflight = _prefix('http_requests_in_progress');
    final pDur = _prefix('http_request_duration_seconds');

    buf.writeln('# HELP $pTotal Total HTTP requests handled by Sparky.');
    buf.writeln('# TYPE $pTotal counter');
    final counterKeys = _requestsTotal.keys.toList()..sort();
    for (final key in counterKeys) {
      final parts = key.split('\t');
      final method = parts[0];
      final status = parts[1];
      buf.writeln(
        '$pTotal{method="${_escapeLabel(method)}",status="${_escapeLabel(status)}"} ${_requestsTotal[key]}',
      );
    }

    buf.writeln('# HELP $pInflight Current HTTP requests being processed.');
    buf.writeln('# TYPE $pInflight gauge');
    buf.writeln('$pInflight $_inFlight');

    buf.writeln(
      '# HELP $pDur HTTP request duration in seconds (histogram for quantiles in Prometheus).',
    );
    buf.writeln('# TYPE $pDur histogram');

    final methods = _histogram.keys.toList()..sort();
    for (final method in methods) {
      final h = _histogram[method]!;
      for (var i = 0; i < _sortedBuckets.length; i++) {
        final le = _formatLe(_sortedBuckets[i]);
        buf.writeln(
          '${pDur}_bucket{method="${_escapeLabel(method)}",le="$le"} ${h.bucketCounts[i]}',
        );
      }
      buf.writeln(
        '${pDur}_bucket{method="${_escapeLabel(method)}",le="+Inf"} ${h.bucketCounts[_sortedBuckets.length]}',
      );
      buf.writeln(
        '${pDur}_sum{method="${_escapeLabel(method)}"} ${_trimFloat(h.sum)}',
      );
      buf.writeln(
        '${pDur}_count{method="${_escapeLabel(method)}"} ${h.count}',
      );
    }

    return buf.toString();
  }

  static String _formatLe(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    final t = v.toString();
    return t.contains('.') ? t : '$t.0';
  }

  static String _trimFloat(double v) {
    final s = v.toString();
    if (s.contains('e') || s.contains('E')) return s;
    if (!s.contains('.')) return s;
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static String _escapeLabel(String v) {
    return v
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
  }
}

/// Per-method histogram: [bucketCounts]\[i\] = count of obs with duration ≤ bound i; last = +Inf.
final class _HistAgg {
  _HistAgg(int bucketLen) : bucketCounts = List<int>.filled(bucketLen + 1, 0);

  final List<int> bucketCounts;
  double sum = 0;
  int count = 0;
}
