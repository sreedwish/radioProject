import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/data/preferences.dart';
import 'package:radio_app/player/auto_drive.dart';
import 'package:radio_app/player/drive_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('maps activities, ignoring low confidence and standing still', () {
    Activity a(ActivityType t, ActivityConfidence c) => Activity(t, c);
    expect(motionOf(a(ActivityType.IN_VEHICLE, ActivityConfidence.HIGH)), Motion.vehicle);
    expect(motionOf(a(ActivityType.IN_VEHICLE, ActivityConfidence.LOW)), Motion.other);
    expect(motionOf(a(ActivityType.WALKING, ActivityConfidence.MEDIUM)), Motion.onFoot);
    expect(motionOf(a(ActivityType.STILL, ActivityConfidence.HIGH)), Motion.other);
  });

  test('enters on vehicle, leaves when the user walks away', () async {
    final c = await _container();
    final logic = c.read(autoDriveProvider).logic;
    logic.handle(Motion.vehicle);
    expect(c.read(driveModeProvider), isTrue);
    logic.handle(Motion.other); // red light
    expect(c.read(driveModeProvider), isTrue);
    logic.handle(Motion.onFoot);
    expect(c.read(driveModeProvider), isFalse);
  });

  test('a manual exit sticks for the rest of the trip', () async {
    final c = await _container();
    final logic = c.read(autoDriveProvider).logic;
    logic.handle(Motion.vehicle);
    c.read(driveModeProvider.notifier).set(false); // user taps ✕
    logic.handle(Motion.vehicle);
    expect(c.read(driveModeProvider), isFalse);
    logic.handle(Motion.onFoot); // trip over
    logic.handle(Motion.vehicle);
    expect(c.read(driveModeProvider), isTrue);
  });

  test('drive mode the user turned on is never switched off automatically', () async {
    final c = await _container();
    final logic = c.read(autoDriveProvider).logic;
    c.read(driveModeProvider.notifier).set(true);
    logic.handle(Motion.onFoot);
    expect(c.read(driveModeProvider), isTrue);
  });
}
