import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_viewport.dart';

void main() {
  for (final dpr in [1.0, 2.75, 3.5]) {
    for (final fitWithinBounds in [false, true]) {
      testWidgets(
        'repeated fullscreen split rotation preserves surface at DPR $dpr contain=$fitWithinBounds',
        (tester) async {
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          var creations = 0;
          var disposals = 0;
          const sizes = [
            Size(960, 540),
            Size(412, 300),
            Size(0, 0),
            Size(1, 1),
            Size(800, 400),
            Size(800, 200),
            Size(500, 200),
            Size(412, 915),
            Size(1280, 800),
            Size(960, 540),
          ];
          Rect? initial;
          Rect? initialWindowed;
          for (var cycle = 0; cycle < 20; cycle++) {
            for (var step = 0; step < sizes.length; step++) {
              final size = sizes[step];
              tester.view.devicePixelRatio = dpr;
              tester.view.physicalSize = size * dpr;
              await tester.pumpWidget(
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: MediaQuery(
                    data: MediaQueryData(size: size, devicePixelRatio: dpr),
                    child: GameSurfaceViewport(
                      fullscreen: step.isEven,
                      isLandscape: size.width > size.height,
                      fitWithinBounds: fitWithinBounds,
                      child: _Probe(
                        onCreate: () => creations++,
                        onDispose: () => disposals++,
                      ),
                    ),
                  ),
                ),
              );
              expect(
                tester.takeException(),
                isNull,
                reason: 'cycle=$cycle step=$step',
              );
              final rect = tester.getRect(
                find.byKey(const Key('stress-canvas')),
              );
              expect(rect.width.isFinite && rect.height.isFinite, isTrue);
              expect(rect.left, greaterThanOrEqualTo(-0.001));
              expect(rect.top, greaterThanOrEqualTo(-0.001));
              expect(rect.right, lessThanOrEqualTo(size.width + 0.001));
              expect(rect.bottom, lessThanOrEqualTo(size.height + 0.001));
              if (size.width > 0 && size.height > 0) {
                expect(rect.width / rect.height, closeTo(1200 / 720, 0.0001));
              }
              if (step == 0) {
                initial ??= rect;
                expect(rect, initial);
              }
              if (step == sizes.length - 1) {
                initialWindowed ??= rect;
                expect(rect, initialWindowed);
              }
              expect(
                creations,
                1,
                reason: 'Resizing must keep the same native surface subtree',
              );
              expect(disposals, 0);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          expect(disposals, 1);
        },
      );
    }
  }
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onCreate, required this.onDispose});
  final VoidCallback onCreate;
  final VoidCallback onDispose;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('stress-canvas'));
}
