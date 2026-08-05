import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_update_service.dart';

String _map(String version, {String? destination}) =>
    '{"meta":{"name":"map","version":"$version"},"data":{"5-6":{"route":{"42":["X","${destination ?? 'Y'}"]}}}}';

void main() {
  test(
    'records a completed manual check with the injected UTC clock',
    () async {
      final checkedAtUtc = DateTime.utc(2026, 8, 5, 16, 0, 45);
      final controller = FcdMapController(
        dataset: FcdMapDataset.parse(_map('2026/07/01/01'), minimumMapCount: 1),
        updater: _Updater((current) async => FcdMapUpToDate(current.version)),
        now: () => checkedAtUtc,
      );
      addTearDown(controller.dispose);

      await controller.checkForUpdates();

      expect(controller.lastCheckedAt, checkedAtUtc);
      expect(controller.lastCheckedAt?.isUtc, isTrue);
    },
  );

  test(
    'hot swaps the immutable dataset without replacing the resolver',
    () async {
      final oldData = FcdMapDataset.parse(
        _map('2026/07/01/01', destination: 'X'),
        minimumMapCount: 1,
      );
      final newData = FcdMapDataset.parse(
        _map('2026/07/28/02'),
        minimumMapCount: 1,
      );
      final controller = FcdMapController(
        dataset: oldData,
        updater: _Updater((_) async => FcdMapUpdated(newData)),
      );
      addTearDown(controller.dispose);

      expect(
        controller.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 42),
        'X',
      );
      await controller.checkForUpdates();
      expect(
        controller.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 42),
        'Y',
      );
      expect(controller.version, newData.version);
    },
  );

  test('coalesces concurrent checks into the same future', () async {
    final completer = Completer<FcdMapUpdateResult>();
    var calls = 0;
    final controller = FcdMapController(
      dataset: FcdMapDataset.parse(_map('2026/07/01/01'), minimumMapCount: 1),
      updater: _Updater((_) {
        calls++;
        return completer.future;
      }),
    );
    addTearDown(controller.dispose);

    final first = controller.checkForUpdates();
    final second = controller.checkForUpdates();

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    completer.complete(FcdMapUpToDate(controller.version));
    await first;
    expect(controller.isChecking, isFalse);
  });
}

final class _Updater implements FcdMapUpdateClient {
  _Updater(this.callback);

  final Future<FcdMapUpdateResult> Function(FcdMapDataset current) callback;

  @override
  Future<FcdMapUpdateResult> checkAndUpdate({required FcdMapDataset current}) =>
      callback(current);
}
