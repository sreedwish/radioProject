import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences.dart';
import 'drive_mode.dart';

/// What the phone says it is doing, boiled down to what matters here.
enum Motion { vehicle, onFoot, other }

Motion motionOf(Activity activity) {
  // Low-confidence guesses flip-flop too much to act on.
  if (activity.confidence == ActivityConfidence.LOW) return Motion.other;
  switch (activity.type) {
    case ActivityType.IN_VEHICLE:
      return Motion.vehicle;
    case ActivityType.WALKING:
    case ActivityType.RUNNING:
      return Motion.onFoot;
    // STILL is deliberately "other": it is what a red light looks like.
    case ActivityType.STILL:
    case ActivityType.ON_BICYCLE:
    case ActivityType.UNKNOWN:
      return Motion.other;
  }
}

/// Turns Drive mode on when the phone detects a vehicle and back off when the
/// user gets out and walks away. Leaving Drive mode by hand wins: it stays off
/// for the rest of that trip.
class AutoDrive {
  AutoDrive(this._ref);

  final Ref _ref;
  StreamSubscription<Activity>? _subscription;
  bool _enteredAutomatically = false;
  bool _suppressedForTrip = false;
  bool _changingItself = false;

  void handle(Motion motion) {
    final drive = _ref.read(driveModeProvider.notifier);
    final driving = _ref.read(driveModeProvider);
    switch (motion) {
      case Motion.vehicle:
        if (driving || _suppressedForTrip) return;
        _enteredAutomatically = true;
        _setDrive(drive, true);
      case Motion.onFoot:
        _suppressedForTrip = false;
        if (driving && _enteredAutomatically) _setDrive(drive, false);
        _enteredAutomatically = false;
      case Motion.other:
        break;
    }
  }

  /// Call when Drive mode changes so a manual exit can be told from our own.
  void driveModeChanged(bool driving) {
    if (_changingItself) return;
    if (driving) {
      _enteredAutomatically = false;
    } else if (_enteredAutomatically) {
      _suppressedForTrip = true;
      _enteredAutomatically = false;
    }
  }

  void _setDrive(DriveModeController drive, bool on) {
    _changingItself = true;
    drive.set(on);
    _changingItself = false;
  }

  Future<void> start({bool askForPermission = false}) async {
    await stop();
    try {
      final plugin = FlutterActivityRecognition.instance;
      var permission = await plugin.checkPermission();
      if (permission == ActivityPermission.DENIED && askForPermission) {
        permission = await plugin.requestPermission();
      }
      if (permission != ActivityPermission.GRANTED) return;
      _subscription = plugin.activityStream.listen(
        (activity) => handle(motionOf(activity)),
        onError: (Object e) => debugPrint('Activity recognition error: $e'),
      );
    } catch (e) {
      debugPrint('Could not start activity recognition: $e');
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

/// The user's "switch automatically when driving" setting (on by default).
class AutoDriveSetting extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(autoDrivePrefKey) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(autoDrivePrefKey, on);
    await ref.read(autoDriveProvider).sync(askForPermission: true);
  }
}

final autoDriveSettingProvider = NotifierProvider<AutoDriveSetting, bool>(
  AutoDriveSetting.new,
);

final autoDriveProvider = Provider<AutoDriveRunner>((ref) {
  final runner = AutoDriveRunner(ref);
  ref.listen(
    driveModeProvider,
    (_, driving) => runner.logic.driveModeChanged(driving),
  );
  ref.onDispose(runner.logic.stop);
  return runner;
});

/// Starts and stops [AutoDrive] to follow the setting.
class AutoDriveRunner {
  AutoDriveRunner(this._ref) : logic = AutoDrive(_ref);

  final Ref _ref;
  final AutoDrive logic;

  /// Applies the setting. Asks for the permission only once on its own (first
  /// run) and again whenever the user flips the switch on.
  Future<void> sync({bool askForPermission = false}) async {
    if (kIsWeb) return; // No activity sensor in the browser.
    final prefs = _ref.read(sharedPreferencesProvider);
    if (!_ref.read(autoDriveSettingProvider)) return logic.stop();
    final alreadyAsked = prefs.getBool(autoDriveAskedPrefKey) ?? false;
    final ask = askForPermission || !alreadyAsked;
    if (ask) await prefs.setBool(autoDriveAskedPrefKey, true);
    await logic.start(askForPermission: ask);
  }
}
