import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_timer_anchor_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('timer anchors round trip through shared preferences', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesNotificationTimerAnchorStore(memberId: 1001);
    final anchors = NotificationTimerAnchors(
      akashi: GlobalNotificationTimerAnchor(
        anchorAt: DateTime.utc(2026, 8, 22, 1),
        signature: 'akashi:1,2',
      ),
      nozaki: GlobalNotificationTimerAnchor(
        anchorAt: DateTime.utc(2026, 8, 22, 2),
        signature: 'nozaki:1,3',
      ),
      moraleByFleet: {
        1: MoraleNotificationTimerAnchor(
          fleetSignature: '1:1,2',
          observedAt: DateTime.utc(2026, 8, 22, 3),
          observedCondition: 40,
          targetAt: DateTime.utc(2026, 8, 22, 3, 9),
        ),
      },
    );

    await store.save(anchors);

    expect(await store.load(), anchors);
    expect(
      await const SharedPreferencesNotificationTimerAnchorStore(
        memberId: 2002,
      ).load(),
      NotificationTimerAnchors.empty,
    );
    expect(
      await const SharedPreferencesNotificationTimerAnchorStore(
        memberId: 0,
      ).load(),
      NotificationTimerAnchors.empty,
    );
  });

  test('malformed persisted timer anchors fall back to empty state', () async {
    SharedPreferences.setMockInitialValues({
      'account.1001.yahagi_notification_timer_anchors': '{bad json',
    });

    expect(
      await const SharedPreferencesNotificationTimerAnchorStore(
        memberId: 1001,
      ).load(),
      NotificationTimerAnchors.empty,
    );
  });
}
