import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'widgets/below_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/preferences.dart';
import 'data/station_repository.dart';
import 'data/stations.dart';
import 'drive_screen.dart';
import 'player/auto_drive.dart';
import 'player/drive_mode.dart';
import 'player/player_controller.dart';
import 'widgets/marquee_text.dart';
import 'widgets/radio_buttons.dart';
import 'widgets/sound_wave.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The browser has no media-notification service to hook into.
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.srdsh.radio_app.audio',
      androidNotificationChannelName: 'Orvibe playback',
      androidNotificationOngoing: true,
    );
  }
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const RadioApp()),
  );
  // Pick up where the listener left off.
  // Browsers block audio until the first click, so don't auto-play on web.
  if (!kIsWeb) unawaited(container.read(tunerProvider.notifier).resume());
  if (!kIsWeb) unawaited(container.read(autoDriveProvider).sync());
  // Android 13+ needs this for the playback notification and lock-screen controls.
  if (!kIsWeb && Platform.isAndroid) await Permission.notification.request();
}

const _accent = kAccent;
// Playful companions to the orange: a soft peach and a sunny yellow.
const _peach = kLogoSecondary;
const _sunny = kPrimary;
const _brown = kOnPrimary;

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Orvibe',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.dark,
        primary: kPrimary,
        onPrimary: kOnPrimary,
        secondary: kAccent,
        surface: kBackground,
      ),
      scaffoldBackgroundColor: kBackground,
      useMaterial3: true,
      sliderTheme: const SliderThemeData(
        trackHeight: 16,
        activeTrackColor: _accent,
        thumbColor: _accent,
        inactiveTrackColor: Colors.white24,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          foregroundColor: Colors.white70,
          selectedBackgroundColor: _accent,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    home: const RadioScreen(),
  );
}

class RadioScreen extends ConsumerWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(driveModeProvider)) return const DriveScreen();
    final tuner = ref.watch(tunerProvider);
    final controller = ref.read(tunerProvider.notifier);
    final state = ref.watch(playerStateProvider).value;
    final player = ref.read(audioPlayerProvider);
    final band = tuner.band;
    final station = ref.watch(currentStationProvider);
    final error = ref.watch(playbackErrorProvider);
    final loadingList = ref.watch(stationsProvider).isLoading;
    final loading =
        station != null &&
        (state?.processingState == ProcessingState.loading ||
            // Browsers keep reporting buffering on live streams that are
            // already playing, so only trust it on native platforms.
            (!kIsWeb && state?.processingState == ProcessingState.buffering));
    final playing = station != null && (state?.playing ?? false);
    final theme = Theme.of(context);
    final landscape = useLandscapeLayout(context);
    final bandSwitch = SizedBox(
      width: 220,
      child: SegmentedButton<Band>(
        expandedInsets: EdgeInsets.zero,
        segments: [
          for (final b in Band.values)
            ButtonSegment(value: b, label: Text(b.label)),
        ],
        selected: {band},
        onSelectionChanged: (s) => controller.setBand(s.first),
      ),
    );
    final driveButton = ExpressiveButton(
      tooltip: 'Drive mode',
      icon: Icons.directions_car_filled_rounded,
      width: 48,
      height: 48,
      radius: BorderRadius.circular(16),
      color: Colors.white.withValues(alpha: 0.14),
      iconColor: Colors.white,
      onPressed: () => ref.read(driveModeProvider.notifier).set(true),
      onLongPress: () => _showDriveSettings(context),
    );
    // In landscape the band switch moves above the frequency instead.
    final topBar = landscape
        ? Align(alignment: Alignment.centerRight, child: driveButton)
        : SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                bandSwitch,
                Align(alignment: Alignment.centerRight, child: driveButton),
              ],
            ),
          );
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (landscape) ...[bandSwitch, const SizedBox(height: 16)],
        Text(
          band.format(tuner.frequency),
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w300,
          ),
        ),
        Text(band.unit, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SoundWave(active: playing && !loading),
        const SizedBox(height: 12),
        MarqueeText(
          loadingList
              ? 'Loading stations…'
              : station == null
              ? 'No signal'
              : error ?? (loading ? 'Buffering…' : station.name),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final tuneButton = landscape ? 40.0 : 48.0;
    final tuneRow = Row(
      children: [
        ExpressiveButton(
          tooltip: 'Tune down',
          icon: Icons.remove_rounded,
          width: tuneButton,
          height: tuneButton,
          radius: BorderRadius.circular(16),
          color: _sunny,
          iconColor: kOnPrimary,
          onPressed: () => controller.step(-1),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(
              context,
            ).copyWith(trackHeight: landscape ? 10 : null),
            child: Slider(
              // ignore: deprecated_member_use
              year2023: false,
              min: band.min,
              max: band.max,
              divisions: band.divisions,
              value: tuner.frequency.clamp(band.min, band.max),
              onChanged: controller.preview,
              onChangeEnd: controller.tune,
            ),
          ),
        ),
        ExpressiveButton(
          tooltip: 'Tune up',
          icon: Icons.add_rounded,
          width: tuneButton,
          height: tuneButton,
          radius: BorderRadius.circular(16),
          color: _sunny,
          iconColor: kOnPrimary,
          onPressed: () => controller.step(1),
        ),
      ],
    );
    final transport = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExpressiveButton(
          tooltip: 'Previous station',
          icon: Icons.skip_previous_rounded,
          width: landscape ? 72 : 88,
          height: landscape ? 56 : 68,
          iconSize: landscape ? 28 : 34,
          radius: BorderRadius.horizontal(
            left: Radius.circular(landscape ? 28 : 34),
            right: Radius.circular(landscape ? 12 : 14),
          ),
          color: _peach,
          iconColor: _brown,
          onPressed: () => controller.seek(-1),
        ),
        const SizedBox(width: 16),
        PlayButton(
          size: landscape ? 80 : 96,
          loading: loading,
          playing: playing,
          onPressed: station == null
              ? null
              : (playing ? player.pause : controller.play),
        ),
        const SizedBox(width: 16),
        ExpressiveButton(
          tooltip: 'Next station',
          icon: Icons.skip_next_rounded,
          width: landscape ? 72 : 88,
          height: landscape ? 56 : 68,
          iconSize: landscape ? 28 : 34,
          radius: BorderRadius.horizontal(
            left: Radius.circular(landscape ? 12 : 14),
            right: Radius.circular(landscape ? 28 : 34),
          ),
          color: _peach,
          iconColor: _brown,
          onPressed: () => controller.seek(1),
        ),
      ],
    );
    final language = SizedBox(
      width: 300,
      child: SegmentedButton<Language>(
        expandedInsets: EdgeInsets.zero,
        segments: [
          for (final l in Language.values)
            ButtonSegment(value: l, label: Text(l.label)),
        ],
        selected: {ref.watch(languageProvider)},
        onSelectionChanged: (s) => controller.setLanguage(s.first),
      ),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(image: orientedBackground(context)),
        child: SafeArea(
          child: PortraitColumn(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  topBar,
                  if (landscape)
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: FitPane(child: info)),
                          const SizedBox(width: 24),
                          Expanded(
                            child: FitPane(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  tuneRow,
                                  const SizedBox(height: 24),
                                  transport,
                                  const SizedBox(height: 24),
                                  language,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Expanded(child: BelowLogo(child: info)),
                    tuneRow,
                    const SizedBox(height: 36),
                    transport,
                    const SizedBox(height: 44),
                    language,
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showDriveSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.directions_car_filled_rounded),
                title: const Text('Switch to Drive mode automatically'),
                subtitle: const Text(
                  'Uses your phone\'s motion detection. Works while the app is open.',
                ),
                value: ref.watch(autoDriveSettingProvider),
                onChanged: (on) =>
                    ref.read(autoDriveSettingProvider.notifier).set(on),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
