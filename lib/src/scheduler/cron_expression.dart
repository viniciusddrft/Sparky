// @author viniciusddrft

/// Standard 5-field cron expression parser: `minute hour day-of-month month day-of-week`.
///
/// Each field supports:
/// - `*` — every value in the field's range
/// - `N` — exact value
/// - `N-M` — inclusive range
/// - `N,M,...` — list of values/ranges
/// - `*/K` — every K units (step, starting at the range minimum)
/// - `N-M/K` — step within a range
///
/// Field ranges:
/// - minute: 0-59
/// - hour: 0-23
/// - day of month: 1-31
/// - month: 1-12
/// - day of week: 0-6 (0 = Sunday, 7 is rejected — use 0 instead)
///
/// Named aliases for months (`jan`..`dec`) and weekdays (`sun`..`sat`) are
/// accepted case-insensitively.
///
/// When both `day-of-month` and `day-of-week` are restricted (neither is `*`),
/// the job fires on days matching **either**, following the same rule as
/// classic cron.
///
/// Seconds are intentionally not supported. For sub-minute cadence use
/// [ScheduledTask.every] with a [Duration].
final class CronExpression {
  final _Field _minute;
  final _Field _hour;
  final _Field _dayOfMonth;
  final _Field _month;
  final _Field _dayOfWeek;
  final String source;

  CronExpression._(
    this.source,
    this._minute,
    this._hour,
    this._dayOfMonth,
    this._month,
    this._dayOfWeek,
  );

  /// Parses a 5-field cron expression.
  ///
  /// Throws [FormatException] on malformed input.
  factory CronExpression.parse(String expression) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      throw FormatException(
        'Cron expression must have 5 fields (minute hour day-of-month month day-of-week); got ${parts.length}.',
        expression,
      );
    }
    return CronExpression._(
      expression,
      _Field.parse(parts[0], 0, 59, name: 'minute'),
      _Field.parse(parts[1], 0, 23, name: 'hour'),
      _Field.parse(parts[2], 1, 31, name: 'day-of-month'),
      _Field.parse(parts[3], 1, 12, aliases: _monthAliases, name: 'month'),
      _Field.parse(parts[4], 0, 6, aliases: _dayOfWeekAliases, name: 'day-of-week'),
    );
  }

  /// Whether [time] (minute precision) matches this expression.
  ///
  /// When both day-of-month and day-of-week are restricted, the match is an
  /// OR between them (classic cron behavior).
  bool matches(DateTime time) {
    if (!_minute.contains(time.minute)) return false;
    if (!_hour.contains(time.hour)) return false;
    if (!_month.contains(time.month)) return false;
    final dow = time.weekday % 7; // Dart: Mon=1..Sun=7 → cron: Sun=0..Sat=6
    final domRestricted = !_dayOfMonth.matchesAll;
    final dowRestricted = !_dayOfWeek.matchesAll;
    if (domRestricted && dowRestricted) {
      return _dayOfMonth.contains(time.day) || _dayOfWeek.contains(dow);
    }
    return _dayOfMonth.contains(time.day) && _dayOfWeek.contains(dow);
  }

  /// First [DateTime] strictly after [from] that matches this expression.
  ///
  /// The search has minute granularity — the returned value always has
  /// `second == 0` and `millisecond == 0`.
  DateTime next(DateTime from) {
    var t = DateTime(from.year, from.month, from.day, from.hour, from.minute)
        .add(const Duration(minutes: 1));
    const maxIterations = 366 * 24 * 60; // one year of minutes
    for (var i = 0; i < maxIterations; i++) {
      if (matches(t)) return t;
      t = t.add(const Duration(minutes: 1));
    }
    throw StateError(
      'CronExpression "$source" did not match within one year from $from',
    );
  }
}

final class _Field {
  final Set<int> values;
  final bool matchesAll;
  final int min;
  final int max;

  _Field(this.values, this.matchesAll, this.min, this.max);

  bool contains(int v) => values.contains(v);

  factory _Field.parse(
    String spec,
    int min,
    int max, {
    Map<String, int>? aliases,
    required String name,
  }) {
    final normalized = spec.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw FormatException('Empty $name field', spec);
    }
    final all = <int>{};
    for (final piece in normalized.split(',')) {
      _parsePiece(piece.trim(), min, max, aliases: aliases, name: name, out: all);
    }
    final matchesAll = all.length == (max - min + 1);
    return _Field(all, matchesAll, min, max);
  }
}

void _parsePiece(
  String piece,
  int min,
  int max, {
  Map<String, int>? aliases,
  required String name,
  required Set<int> out,
}) {
  if (piece.isEmpty) {
    throw FormatException('Empty segment in $name field');
  }
  var step = 1;
  var body = piece;
  final slash = piece.indexOf('/');
  if (slash >= 0) {
    body = piece.substring(0, slash);
    final stepStr = piece.substring(slash + 1);
    step = int.tryParse(stepStr) ??
        (throw FormatException('Invalid step "$stepStr" in $name field'));
    if (step < 1) {
      throw FormatException('Step must be >= 1 in $name field');
    }
  }

  int rangeStart, rangeEnd;
  if (body == '*') {
    rangeStart = min;
    rangeEnd = max;
  } else if (body.contains('-')) {
    final parts = body.split('-');
    if (parts.length != 2) {
      throw FormatException('Invalid range "$body" in $name field');
    }
    rangeStart = _resolveValue(parts[0], min, max, aliases, name);
    rangeEnd = _resolveValue(parts[1], min, max, aliases, name);
    if (rangeStart > rangeEnd) {
      throw FormatException(
        'Range start > end ($rangeStart-$rangeEnd) in $name field',
      );
    }
  } else {
    final single = _resolveValue(body, min, max, aliases, name);
    if (slash < 0) {
      out.add(single);
      return;
    }
    rangeStart = single;
    rangeEnd = max;
  }

  for (var v = rangeStart; v <= rangeEnd; v += step) {
    out.add(v);
  }
}

int _resolveValue(
  String raw,
  int min,
  int max,
  Map<String, int>? aliases,
  String name,
) {
  final lower = raw.toLowerCase();
  final alias = aliases?[lower];
  final value = alias ?? int.tryParse(lower);
  if (value == null) {
    throw FormatException('Invalid value "$raw" in $name field');
  }
  if (value < min || value > max) {
    throw FormatException(
      'Value $value out of range [$min-$max] in $name field',
    );
  }
  return value;
}

const _monthAliases = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

const _dayOfWeekAliases = {
  'sun': 0,
  'mon': 1,
  'tue': 2,
  'wed': 3,
  'thu': 4,
  'fri': 5,
  'sat': 6,
};
