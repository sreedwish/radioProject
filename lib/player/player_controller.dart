import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/preferences.dart';
import '../data/station_repository.dart';
import '../data/stations.dart';

final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final playerStateProvider = StreamProvider<PlayerState>(
  (ref) => ref.watch(audioPlayerProvider).playerStateStream,
);

class TunerState {
  const TunerState({required this.band, required this.frequency});
  final Band band;
  final double frequency;
}

class PlaybackError extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) => state = message;
}

final playbackErrorProvider = NotifierProvider<PlaybackError, String?>(
  PlaybackError.new,
);

class TunerController extends Notifier<TunerState> {
  int _tuneId = 0;
  Band? _queueBand;
  List<Station> _queue = const [];
  Uri? _artUri;

  /// The wallpaper as a file, since notification artwork needs a URI.
  Future<Uri?> _artwork() async {
    if (kIsWeb) return null;
    if (_artUri != null) return _artUri;
    final file = File('${Directory.systemTemp.path}/orvibe_bg.png');
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/images/background.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return _artUri = file.uri;
  }

  @override
  TunerState build() {
    // Next/previous from the notification or lock screen move the dial too.
    ref.read(audioPlayerProvider).currentIndexStream.listen((index) {
      if (index == null || index >= _queue.length) return;
      final station = _queue[index];
      if (station.band != state.band ||
          (station.frequency - state.frequency).abs() > 1e-6) {
        ref.read(playbackErrorProvider.notifier).set(null);
        state = TunerState(band: station.band, frequency: station.frequency);
        _save(station);
      }
    });
    // Errors that happen after the source loaded (e.g. the stream drops).
    ref
        .read(audioPlayerProvider)
        .playbackEventStream
        .listen(
          (_) {},
          onError: (Object e, StackTrace _) {
            debugPrint('Playback error: $e');
            ref.read(playbackErrorProvider.notifier).set('Stream unavailable');
          },
        );
    final prefs = ref.read(sharedPreferencesProvider);
    final band =
        Band.values
            .where((b) => b.name == prefs.getString(bandPrefKey))
            .firstOrNull ??
        Band.fm;
    final saved = prefs.getDouble(frequencyPrefKey) ?? band.min;
    return TunerState(band: band, frequency: band.snap(saved));
  }

  void _save(Station? station) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(bandPrefKey, state.band.name);
    prefs.setDouble(frequencyPrefKey, state.frequency);
    if (station == null) {
      prefs.remove(stationPrefKey);
    } else {
      prefs.setString(stationPrefKey, station.id);
    }
  }

  /// Plays the station that was on when the app was last used, or the first
  /// FM station on a first run.
  Future<void> resume() async {
    final stations = await ref.read(stationsProvider.future);
    final savedId = ref
        .read(sharedPreferencesProvider)
        .getString(stationPrefKey);
    final target =
        stations.where((s) => s.id == savedId).firstOrNull ??
        stationAt(stations, state.band, state.frequency) ??
        stations.where((s) => s.band == Band.fm).firstOrNull ??
        stations.firstOrNull;
    if (target == null) return;
    state = TunerState(band: target.band, frequency: target.frequency);
    await _apply();
  }

  /// Starts playback. Browsers block audio until the first tap, so on web
  /// nothing is loaded yet: the first press has to load the station too.
  Future<void> play() async {
    if (_queue.isEmpty) return _apply();
    unawaited(ref.read(audioPlayerProvider).play());
  }

  /// Moves the dial without changing the audio (used while dragging).
  void preview(double frequency) => state = TunerState(
    band: state.band,
    frequency: state.band.snap(frequency),
  );

  /// Moves the dial and plays whatever station is at that frequency.
  Future<void> tune(double frequency) async {
    state = TunerState(band: state.band, frequency: state.band.snap(frequency));
    await _apply();
  }

  /// Switches the station list to [language] and starts its first FM station.
  Future<void> setLanguage(Language language) async {
    if (language == ref.read(languageProvider)) return;
    ref.read(languageProvider.notifier).set(language);
    final stations = await ref.read(stationsProvider.future);
    final first =
        stations.where((s) => s.band == Band.fm).firstOrNull ??
        stations.firstOrNull;
    final band = first?.band ?? Band.fm;
    state = TunerState(band: band, frequency: first?.frequency ?? band.min);
    await _apply();
  }

  Future<void> setBand(Band band) async {
    if (band == state.band) return;
    final stations = await ref.read(stationsProvider.future);
    final first = stations.where((s) => s.band == band).firstOrNull;
    state = TunerState(band: band, frequency: first?.frequency ?? band.min);
    await _apply();
  }

  Future<void> step(int direction) =>
      tune(state.frequency + direction * state.band.step);

  /// Jumps to the next station up (1) or down (-1) the dial, wrapping around.
  Future<void> seek(int direction) async {
    final stations = await ref.read(stationsProvider.future);
    final list = stations.where((s) => s.band == state.band).toList()
      ..sort((a, b) => a.frequency.compareTo(b.frequency));
    if (list.isEmpty) return;
    final f = state.frequency;
    final next = direction > 0
        ? list.firstWhere(
            (s) => s.frequency > f + 1e-6,
            orElse: () => list.first,
          )
        : list.lastWhere(
            (s) => s.frequency < f - 1e-6,
            orElse: () => list.last,
          );
    return tune(next.frequency);
  }

  Future<void> _apply() async {
    final player = ref.read(audioPlayerProvider);
    final id = ++_tuneId;
    ref.read(playbackErrorProvider.notifier).set(null);
    final all = await ref.read(stationsProvider.future);
    if (id != _tuneId) return;
    final station = stationAt(all, state.band, state.frequency);
    _save(station);
    if (station == null) {
      await player.stop();
      return;
    }
    try {
      final art = await _artwork();
      if (id != _tuneId) return;
      // A playlist of the band's stations gives the notification next/previous.
      final list = all.where((s) => s.band == state.band).toList()
        ..sort((a, b) => a.frequency.compareTo(b.frequency));
      final index = list.indexWhere((s) => s.id == station.id);
      final sameQueue =
          _queueBand == state.band &&
          _queue.length == list.length &&
          [
            for (var i = 0; i < list.length; i++) _queue[i].id == list[i].id,
          ].every((e) => e);
      if (sameQueue) {
        await player.seek(Duration.zero, index: index);
      } else {
        _queueBand = state.band;
        _queue = list;
        await player.setAudioSources([
          for (final s in list)
            AudioSource.uri(
              Uri.parse(s.url),
              tag: MediaItem(
                id: s.id,
                title: s.name,
                album: 'Orvibe',
                artist: '${s.band.format(s.frequency)} ${s.band.unit}',
                artUri: art,
              ),
            ),
        ], initialIndex: index);
        await player.setLoopMode(LoopMode.all);
      }
      // play() only completes when playback stops, so don't await it.
      if (id == _tuneId) unawaited(player.play());
    } catch (e) {
      debugPrint('Could not play ${station.name} (${station.url}): $e');
      if (id == _tuneId) {
        ref
            .read(playbackErrorProvider.notifier)
            .set('Could not play this station');
      }
    }
  }
}

final tunerProvider = NotifierProvider<TunerController, TunerState>(
  TunerController.new,
);

final currentStationProvider = Provider<Station?>((ref) {
  final tuner = ref.watch(tunerProvider);
  final list = ref.watch(stationsProvider).value ?? const <Station>[];
  return stationAt(list, tuner.band, tuner.frequency);
});

class VolumeController extends Notifier<double> {
  @override
  double build() => 1.0;

  void set(double volume) {
    state = volume.clamp(0.0, 1.0);
    ref.read(audioPlayerProvider).setVolume(state);
  }

  void change(double delta) => set(state + delta);
}

final volumeProvider = NotifierProvider<VolumeController, double>(
  VolumeController.new,
);
