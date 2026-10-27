import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

const languagePrefKey = 'language';
const bandPrefKey = 'band';
const frequencyPrefKey = 'frequency';
const stationPrefKey = 'station';
const drivePrefKey = 'drive';
const autoDrivePrefKey = 'autoDrive';
const autoDriveAskedPrefKey = 'autoDriveAsked';
