import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/preferences.dart';

/// Whether the simplified, big-button driving screen is showing. The choice is
/// remembered, and the screen stays awake while it is on.
class DriveModeController extends Notifier<bool> {
  @override
  bool build() {
    final on =
        ref.read(sharedPreferencesProvider).getBool(drivePrefKey) ?? false;
    if (on) _keepAwake(true);
    return on;
  }

  void set(bool on) {
    state = on;
    ref.read(sharedPreferencesProvider).setBool(drivePrefKey, on);
    _keepAwake(on);
  }

  Future<void> _keepAwake(bool on) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {
      // Not worth failing the mode switch over.
    }
  }
}

final driveModeProvider = NotifierProvider<DriveModeController, bool>(
  DriveModeController.new,
);
