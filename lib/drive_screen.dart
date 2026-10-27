import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'widgets/below_logo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'data/station_repository.dart';
import 'data/stations.dart';
import 'player/drive_mode.dart';
import 'player/player_controller.dart';
import 'widgets/marquee_text.dart';
import 'widgets/radio_buttons.dart';
import 'widgets/sound_wave.dart';

const _accent = kAccent;
const _peach = kLogoSecondary;
const _brown = kOnPrimary;

/// A stripped-down screen for use while driving: a few huge targets, no
/// sliders, tap anywhere to play/pause, swipe to change station.
class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final language = ref.watch(languageProvider);
    final theme = Theme.of(context);
    void tap(VoidCallback action) {
      HapticFeedback.mediumImpact();
      action();
    }

    void togglePlay() {
      if (station == null) return;
      tap(playing ? player.pause : controller.play);
    }

    final landscape = useLandscapeLayout(context);
    final bandSwitch = SizedBox(
      width: 200,
      child: SegmentedButton<Band>(
        expandedInsets: EdgeInsets.zero,
        segments: [
          for (final b in Band.values)
            ButtonSegment(value: b, label: Text(b.label)),
        ],
        selected: {band},
        onSelectionChanged: (s) => tap(() => controller.setBand(s.first)),
      ),
    );
    final topBar = Row(
      children: [
        ExpressiveButton(
          tooltip: 'Exit drive mode',
          icon: Icons.close_rounded,
          width: 56,
          height: 56,
          radius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.14),
          iconColor: Colors.white,
          onPressed: () => ref.read(driveModeProvider.notifier).set(false),
        ),
        const Spacer(),
        if (!landscape) bandSwitch,
      ],
    );
    final info = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: togglePlay,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -300) tap(() => controller.seek(1));
        if (v > 300) tap(() => controller.seek(-1));
      },
      child: BelowLogo(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (landscape) ...[bandSwitch, const SizedBox(height: 16)],
            Text(
              band.format(tuner.frequency),
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 110,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
            Text(band.unit, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            SoundWave(active: playing && !loading, height: 40),
            const SizedBox(height: 16),
            MarqueeText(
              loadingList
                  ? 'Loading stations…'
                  : station == null
                  ? 'No signal'
                  : error ?? (loading ? 'Buffering…' : station.name),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tap to play / pause  ·  swipe to change station',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
    final transport = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: ExpressiveButton(
            tooltip: 'Previous station',
            icon: Icons.skip_previous_rounded,
            width: double.infinity,
            height: landscape ? 104 : 128,
            iconSize: landscape ? 44 : 52,
            radius: BorderRadius.horizontal(
              left: Radius.circular(landscape ? 52 : 64),
              right: Radius.circular(landscape ? 16 : 20),
            ),
            color: _peach,
            iconColor: _brown,
            onPressed: () => tap(() => controller.seek(-1)),
          ),
        ),
        const SizedBox(width: 14),
        PlayButton(
          size: landscape ? 116 : 140,
          loading: loading,
          playing: playing,
          onPressed: station == null ? null : togglePlay,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ExpressiveButton(
            tooltip: 'Next station',
            icon: Icons.skip_next_rounded,
            width: double.infinity,
            height: landscape ? 104 : 128,
            iconSize: landscape ? 44 : 52,
            radius: BorderRadius.horizontal(
              left: Radius.circular(landscape ? 16 : 20),
              right: Radius.circular(landscape ? 52 : 64),
            ),
            color: _peach,
            iconColor: _brown,
            onPressed: () => tap(() => controller.seek(1)),
          ),
        ),
      ],
    );
    final languages = Row(
      children: [
        for (final l in Language.values) ...[
          if (l != Language.values.first) const SizedBox(width: 12),
          Expanded(
            child: _LanguageTile(
              label: l.label,
              selected: l == language,
              onTap: () => tap(() => controller.setLanguage(l)),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(image: orientedBackground(context)),
        child: SafeArea(
          child: PortraitColumn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  topBar,
                  if (landscape)
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: info),
                          const SizedBox(width: 20),
                          Expanded(
                            child: FitPane(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  transport,
                                  const SizedBox(height: 20),
                                  languages,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Expanded(child: info),
                    transport,
                    const SizedBox(height: 24),
                    languages,
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

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    height: 76,
    decoration: BoxDecoration(
      color: selected ? _accent : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: selected ? _accent : Colors.white24),
    ),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}
