import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/widgets/marquee_text.dart';
import 'package:radio_app/widgets/radio_buttons.dart';
import 'package:radio_app/widgets/sound_wave.dart';

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool playing = false, loading = false, enabled = true;
  String title = 'Short';
  void set(void Function() f) => setState(f);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(
      colorSchemeSeed: Colors.deepOrange,
      brightness: Brightness.dark,
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SoundWave(active: playing && !loading),
            MarqueeText(title),
            Slider(value: 0.5, onChanged: (_) {}),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExpressiveButton(
                  icon: Icons.skip_previous_rounded,
                  tooltip: 'p',
                  width: 88,
                  height: 68,
                  radius: BorderRadius.circular(20),
                  color: Colors.blue,
                  iconColor: Colors.white,
                  onPressed: () {},
                ),
                PlayButton(
                  loading: loading,
                  playing: playing,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('rapid state changes do not throw', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _Harness());
    final h = tester.state<_HarnessState>(find.byType(_Harness));
    const long =
        'A really long radio station name that definitely overflows the width of the screen';
    for (var i = 0; i < 12; i++) {
      h.set(() {
        h.playing = i.isEven;
        h.loading = i % 3 == 0;
        h.enabled = i % 4 != 1;
        h.title = i % 2 == 0 ? long : 'Short $i';
      });
      await tester.pump(const Duration(milliseconds: 90));
    }
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(PlayButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
