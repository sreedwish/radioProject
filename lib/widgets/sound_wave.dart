import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small audio-signal visual: slim bars that bounce to an imagined beat and
/// stay white. It grows in while [active] (playing or
/// buffering) and shrinks away when it isn't, keeping its space reserved so
/// the layout doesn't jump.
class SoundWave extends StatefulWidget {
  const SoundWave({
    super.key,
    required this.active,
    this.height = 32,
    this.widthFactor = 0.8,
  });

  final bool active;
  final double height;

  /// Share of the available width the wave occupies, centred.
  final double widthFactor;

  @override
  State<SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<SoundWave> with TickerProviderStateMixin {
  late final _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final _presence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SoundWave old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _beat.repeat();
      _presence.forward();
    } else {
      // Shrink away first, then stop the tickers.
      _presence.reverse().whenComplete(() {
        if (mounted && !widget.active) {
          _beat.stop();
        }
      });
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: FractionallySizedBox(
        widthFactor: widget.widthFactor,
        child: SizedBox(
          height: widget.height,
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: Listenable.merge([_beat, _presence]),
              builder: (context, _) => CustomPaint(
                painter: _BarsPainter(
                  beat: _beat.value * 2 * math.pi,
                  presence: Curves.easeOutCubic.transform(_presence.value),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({required this.beat, required this.presence});

  final double beat;
  final double presence;

  @override
  void paint(Canvas canvas, Size size) {
    if (presence < 0.01) return;
    // A fixed bar pitch keeps the density the same on every screen width.
    final bars = math.max(5, (size.width / 7).floor());
    final slot = size.width / bars;
    final barWidth = math.min(slot * 0.5, 3.0);
    final mid = size.height / 2;
    for (var i = 0; i < bars; i++) {
      // Two out-of-step sines per bar look like a live signal, and the middle
      // bars swing furthest.
      final wobble =
          0.5 * math.sin(beat * (1 + i % 3) + i * 1.7) +
          0.5 * math.sin(beat * 2 + i * 0.9);
      final envelope = 0.45 + 0.55 * math.sin((i + 0.5) / bars * math.pi);
      final level = (0.18 + 0.82 * (0.5 + 0.5 * wobble)) * envelope;
      final half = math.max(barWidth / 2, mid * level * presence);
      final x = slot * (i + 0.5);
      final color = Colors.white.withValues(alpha: presence);
      canvas.drawLine(
        Offset(x, mid - half),
        Offset(x, mid + half),
        Paint()
          ..color = color
          ..strokeWidth = barWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.beat != beat || old.presence != presence;
}
