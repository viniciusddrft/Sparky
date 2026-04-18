// @author viniciusddrft

import 'dart:async';

import 'package:sparky/sparky.dart';
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  group('CronExpression.parse', () {
    test('matches every-minute expression', () {
      final cron = CronExpression.parse('* * * * *');
      final any = DateTime(2026, 4, 18, 12, 34);
      expect(cron.matches(any), isTrue);
    });

    test('matches specific minute + hour', () {
      final cron = CronExpression.parse('30 9 * * *');
      expect(cron.matches(DateTime(2026, 4, 18, 9, 30)), isTrue);
      expect(cron.matches(DateTime(2026, 4, 18, 9, 31)), isFalse);
      expect(cron.matches(DateTime(2026, 4, 18, 10, 30)), isFalse);
    });

    test('step expressions', () {
      final cron = CronExpression.parse('*/5 * * * *');
      expect(cron.matches(DateTime(2026, 4, 18, 1)), isTrue);
      expect(cron.matches(DateTime(2026, 4, 18, 1, 5)), isTrue);
      expect(cron.matches(DateTime(2026, 4, 18, 1, 7)), isFalse);
    });

    test('range and list combined', () {
      final cron = CronExpression.parse('0 9-17 * * mon-fri');
      // Monday at 10:00
      expect(cron.matches(DateTime(2026, 4, 13, 10)), isTrue);
      // Saturday at 10:00
      expect(cron.matches(DateTime(2026, 4, 18, 10)), isFalse);
      // Monday at 18:00 (out of hour range)
      expect(cron.matches(DateTime(2026, 4, 13, 18)), isFalse);
    });

    test('named aliases (case-insensitive)', () {
      final cron = CronExpression.parse('0 0 1 JAN,jul *');
      expect(cron.matches(DateTime(2026)), isTrue);
      expect(cron.matches(DateTime(2026, 7)), isTrue);
      expect(cron.matches(DateTime(2026, 3)), isFalse);
    });

    test('day-of-month and day-of-week OR when both restricted', () {
      // Classic cron: at 00:00 on the 1st OR on Sunday
      final cron = CronExpression.parse('0 0 1 * sun');
      expect(cron.matches(DateTime(2026, 4)), isTrue); // 1st
      expect(cron.matches(DateTime(2026, 4, 5)), isTrue); // Sunday
      expect(cron.matches(DateTime(2026, 4, 6)), isFalse); // Mon, not 1st
    });

    test('rejects malformed expressions', () {
      expect(() => CronExpression.parse('* * * *'), throwsFormatException);
      expect(() => CronExpression.parse('60 * * * *'), throwsFormatException);
      expect(() => CronExpression.parse('* * * * 7'), throwsFormatException);
      expect(() => CronExpression.parse('a * * * *'), throwsFormatException);
      expect(() => CronExpression.parse('5-2 * * * *'), throwsFormatException);
      expect(() => CronExpression.parse('*/0 * * * *'), throwsFormatException);
    });

    test('next() returns the next matching minute', () {
      final cron = CronExpression.parse('30 9 * * *');
      final from = DateTime(2026, 4, 18, 9, 30);
      final next = cron.next(from);
      expect(next, DateTime(2026, 4, 19, 9, 30));
    });

    test('next() skips to following day when past cutoff', () {
      final cron = CronExpression.parse('0 3 * * *');
      final from = DateTime(2026, 4, 18, 10);
      expect(cron.next(from), DateTime(2026, 4, 19, 3));
    });
  });

  group('ScheduledTask', () {
    test('cron task has parsed expression', () {
      final task = ScheduledTask(
        expression: '*/5 * * * *',
        job: () {},
        name: 'sync',
      );
      expect(task.cron, isNotNull);
      expect(task.interval, isNull);
      expect(task.name, 'sync');
    });

    test('every task has interval', () {
      final task = ScheduledTask.every(
        interval: const Duration(seconds: 30),
        job: () {},
      );
      expect(task.cron, isNull);
      expect(task.interval, const Duration(seconds: 30));
    });
  });

  group('Scheduler lifecycle', () {
    test('every task fires and stops cleanly with server close', () async {
      final runs = <int>[];
      var counter = 0;

      final client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/ping',
              middleware: (_) async => const Response.ok(body: 'ok')),
        ],
        scheduler: SchedulerConfig(tasks: [
          ScheduledTask.every(
            interval: const Duration(milliseconds: 50),
            job: () {
              runs.add(++counter);
            },
          ),
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));
      await client.close();
      final snapshot = runs.length;
      expect(snapshot, greaterThanOrEqualTo(3));

      // After close, no more ticks should fire.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(runs.length, snapshot);
    });

    test('onError receives thrown exceptions without killing scheduler',
        () async {
      final errors = <Object>[];
      var okRuns = 0;
      var callCount = 0;

      final client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        scheduler: SchedulerConfig(
          onError: (task, error, stack) => errors.add(error),
          tasks: [
            ScheduledTask.every(
              interval: const Duration(milliseconds: 40),
              job: () {
                callCount++;
                if (callCount == 1) throw StateError('boom');
                okRuns++;
              },
            ),
          ],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));
      await client.close();

      expect(errors.length, greaterThanOrEqualTo(1));
      expect(errors.first, isA<StateError>());
      expect(okRuns, greaterThanOrEqualTo(1));
    });

    test('allowOverlap=false serializes slow jobs', () async {
      var concurrent = 0;
      var maxConcurrent = 0;

      final client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        scheduler: SchedulerConfig(tasks: [
          ScheduledTask.every(
            interval: const Duration(milliseconds: 20),
            job: () async {
              concurrent++;
              maxConcurrent =
                  concurrent > maxConcurrent ? concurrent : maxConcurrent;
              await Future<void>.delayed(const Duration(milliseconds: 60));
              concurrent--;
            },
          ),
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await client.close();

      expect(maxConcurrent, 1);
    });

    test('disabled scheduler never fires', () async {
      var ran = false;

      final client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        scheduler: SchedulerConfig(
          enabled: false,
          tasks: [
            ScheduledTask.every(
              interval: const Duration(milliseconds: 20),
              job: () => ran = true,
            ),
          ],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await client.close();
      expect(ran, isFalse);
    });

    test('stop awaits in-flight job', () async {
      final completer = Completer<void>();
      var finished = false;

      final client = await SparkyTestClient.boot(
        routes: [
          RouteHttp.get('/x',
              middleware: (_) async => const Response.ok(body: '')),
        ],
        scheduler: SchedulerConfig(tasks: [
          ScheduledTask.every(
            interval: const Duration(milliseconds: 20),
            allowOverlap: true,
            job: () async {
              await completer.future;
              finished = true;
            },
          ),
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final stopFuture = client.close();
      // Release the in-flight job; close() must wait for it.
      completer.complete();
      await stopFuture;
      expect(finished, isTrue);
    });
  });
}
