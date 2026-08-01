import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_progress.dart';

void main() {
  test('clamps operation progress before start and after completion', () {
    final start = DateTime.utc(2026, 7, 30, 10);
    final end = DateTime.utc(2026, 7, 30, 12);

    expect(
      operationProgress(
        now: DateTime.utc(2026, 7, 30, 9),
        start: start,
        end: end,
      ),
      0,
    );
    expect(
      operationProgress(
        now: DateTime.utc(2026, 7, 30, 13),
        start: start,
        end: end,
      ),
      1,
    );
  });

  test('calculates operation progress from elapsed duration', () {
    final progress = operationProgress(
      now: DateTime.utc(2026, 7, 30, 10, 30),
      start: DateTime.utc(2026, 7, 30, 10),
      end: DateTime.utc(2026, 7, 30, 12),
    );

    expect(progress, 0.25);
  });

  test('returns zero when duration is not valid', () {
    final time = DateTime.utc(2026, 7, 30, 10);

    expect(operationProgress(now: time, start: time, end: time), 0);
  });

  test('formats durations as HH:MM:SS', () {
    expect(
      formatOperationDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '02:03:04',
    );
    expect(
      formatOperationDuration(const Duration(hours: 0, minutes: 0, seconds: 0)),
      '00:00:00',
    );
    expect(formatOperationDuration(const Duration(hours: 25)), '25:00:00');
  });

  testWidgets('countdown shows remaining time and completed text', (
    tester,
  ) async {
    final future = DateTime.now().toUtc().add(const Duration(hours: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OperationCountdownText(
                completionTime: future,
                completedText: '已完成',
              ),
              OperationCountdownText(
                completionTime: null,
                completedText: '已完成',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining(':'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('countdown stops ticking after completion', (tester) async {
    final past = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationCountdownText(
            completionTime: past,
            completedText: '已归还',
          ),
        ),
      ),
    );
    expect(find.text('已归还'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
