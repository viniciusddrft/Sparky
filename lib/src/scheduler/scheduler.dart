// @author viniciusddrft

import 'dart:async';

import 'cron_expression.dart';

/// Callback executed by a [ScheduledTask].
///
/// Async work is awaited before the next tick is scheduled. Throwing is
/// swallowed by the scheduler and forwarded to [SchedulerConfig.onError], so
/// a bad job never crashes the server loop.
typedef ScheduledJob = FutureOr<void> Function();

/// A single job scheduled either by cron expression or fixed interval.
///
/// Use [ScheduledTask] (cron) for wall-clock cadence (`'0 3 * * *'` = 03:00
/// every day), and [ScheduledTask.every] for simple periodic work
/// (`every: Duration(seconds: 30)`).
final class ScheduledTask {
  /// Human-readable name for logs.
  final String name;

  /// Parsed cron expression. Null when [interval] is set.
  final CronExpression? cron;

  /// Fixed interval between runs. Null when [cron] is set.
  final Duration? interval;

  /// Callback executed on each tick.
  final ScheduledJob job;

  /// When `false`, a tick is skipped if the previous run has not finished.
  /// Defaults to `true` for cron tasks and `false` for interval tasks — this
  /// keeps long-running jobs from overlapping themselves by default.
  final bool allowOverlap;

  ScheduledTask({
    required String expression,
    required this.job,
    this.name = 'task',
    this.allowOverlap = true,
  })  : cron = CronExpression.parse(expression),
        interval = null;

  ScheduledTask.every({
    required Duration interval,
    required this.job,
    this.name = 'task',
    this.allowOverlap = false,
    // ignore: prefer_initializing_formals
  })  : interval = interval,
        cron = null,
        assert(interval > Duration.zero, 'interval must be positive');
}

/// Scheduler configuration passed to `Sparky.single(scheduler: ...)`.
///
/// The scheduler starts automatically when [Sparky.ready] completes and is
/// stopped on [Sparky.close]. Each isolate in [Sparky.cluster] runs its own
/// scheduler — if you need exactly-once execution across isolates, run jobs
/// only when `isolateIndex == 0` in the factory or use external locking.
final class SchedulerConfig {
  /// Tasks to register. May be empty.
  final List<ScheduledTask> tasks;

  /// Invoked when a [ScheduledJob] throws. Defaults to logging via `print`.
  final void Function(ScheduledTask task, Object error, StackTrace stack)?
      onError;

  /// When false, no scheduler is started (useful to disable via env flag).
  final bool enabled;

  const SchedulerConfig({
    required this.tasks,
    this.onError,
    this.enabled = true,
  });
}

/// Runtime handle for [SchedulerConfig]. Internal — managed by [Sparky].
final class Scheduler {
  final SchedulerConfig config;
  final List<_RunningTask> _running = [];
  bool _started = false;
  bool _stopped = false;

  Scheduler(this.config);

  bool get isRunning => _started && !_stopped;

  /// Starts all tasks. Idempotent — subsequent calls are no-ops.
  void start() {
    if (_started || !config.enabled) return;
    _started = true;
    final now = DateTime.now();
    for (final task in config.tasks) {
      if (task.cron != null) {
        _running.add(_CronRunning(task, this)..scheduleNext(now));
      } else {
        _running.add(_IntervalRunning(task, this)..scheduleNext(now));
      }
    }
  }

  /// Stops all tasks. After calling [stop], [start] cannot be used again.
  ///
  /// Waits for any in-flight [ScheduledJob] to finish before completing.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    for (final r in _running) {
      r._timer?.cancel();
    }
    final pending = [
      for (final r in _running)
        if (r._inFlight != null) r._inFlight!,
    ];
    _running.clear();
    await Future.wait(pending.map((f) => f.catchError((_) {})));
  }

  void _reportError(ScheduledTask task, Object error, StackTrace stack) {
    final handler = config.onError;
    if (handler != null) {
      handler(task, error, stack);
    } else {
      // ignore: avoid_print
      print('[sparky.scheduler] ${task.name} failed: $error');
    }
  }
}

abstract class _RunningTask {
  _RunningTask(this.task, this.scheduler);

  final ScheduledTask task;
  final Scheduler scheduler;
  Timer? _timer;
  Future<void>? _inFlight;

  void scheduleNext(DateTime from);

  Future<void> _runOnce(DateTime expected) async {
    if (!task.allowOverlap && _inFlight != null) {
      // Skip: previous run still in flight. Next tick is already scheduled
      // by the wrapper that called us.
      return;
    }
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      await Future<void>.sync(() async => await task.job());
    } catch (e, st) {
      scheduler._reportError(task, e, st);
    } finally {
      _inFlight = null;
      completer.complete();
    }
  }
}

final class _CronRunning extends _RunningTask {
  _CronRunning(super.task, super.scheduler);

  @override
  void scheduleNext(DateTime from) {
    if (scheduler._stopped) return;
    final next = task.cron!.next(from);
    final delay = next.difference(DateTime.now());
    final effective = delay.isNegative ? Duration.zero : delay;
    _timer = Timer(effective, () async {
      if (scheduler._stopped) return;
      // Schedule the following tick immediately so long-running jobs don't
      // drift the wall-clock cadence when allowOverlap is true.
      scheduleNext(next);
      await _runOnce(next);
    });
  }
}

final class _IntervalRunning extends _RunningTask {
  _IntervalRunning(super.task, super.scheduler);

  @override
  void scheduleNext(DateTime from) {
    if (scheduler._stopped) return;
    _timer = Timer(task.interval!, () async {
      if (scheduler._stopped) return;
      // Interval tasks chain: run, then schedule the next tick from now.
      // With allowOverlap=false (the default), a slow run delays the next
      // tick to avoid pile-ups.
      if (task.allowOverlap) {
        scheduleNext(DateTime.now());
        await _runOnce(DateTime.now());
      } else {
        await _runOnce(DateTime.now());
        scheduleNext(DateTime.now());
      }
    });
  }
}
