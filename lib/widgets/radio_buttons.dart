import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A chunky button that squishes down and springs back when pressed, in the
/// spirit of Material 3 Expressive.
class ExpressiveButton extends StatefulWidget {
  const ExpressiveButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
    required this.iconColor,
    this.onLongPress,
    this.width = 56,
    this.height = 56,
    this.radius = const BorderRadius.all(Radius.circular(20)),
    this.iconSize = 28,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Color color;
  final Color iconColor;
  final double width;
  final double height;
  final BorderRadius radius;
  final double iconSize;

  @override
  State<ExpressiveButton> createState() => _ExpressiveButtonState();
}

class _ExpressiveButtonState extends State<ExpressiveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: widget.radius);
    return AnimatedScale(
      scale: _pressed ? 0.85 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Tooltip(
        message: widget.tooltip,
        child: Material(
          color: widget.color,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onHighlightChanged: (down) => setState(() => _pressed = down),
            onTap: widget.onPressed,
            onLongPress: widget.onLongPress,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big play/pause button. Its corners round off into a circle while
/// playing and relax back into a squircle when paused.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.loading,
    required this.playing,
    required this.onPressed,
    this.size = 96,
  });

  final bool loading;
  final bool playing;
  final VoidCallback? onPressed;
  final double size;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final targetRadius = widget.playing ? widget.size / 2 : widget.size * 0.32;
    return AnimatedScale(
      scale: _pressed ? 0.88 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        // Only the corner radius gets the springy curve: overshoot is harmless
        // there, but it would push a shadow's blur radius below zero.
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: targetRadius),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            final radius = BorderRadius.circular(
              value.clamp(0.0, widget.size / 2),
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabled
                      ? const [kLight, kLogoSecondary]
                      : const [Colors.white24, Colors.white12],
                ),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFFE040FB,
                          ).withValues(alpha: 0.55),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            );
          },
          child: InkWell(
            onHighlightChanged: (down) => setState(() => _pressed = down),
            onTap: widget.onPressed,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: RotationTransition(
                    turns: Tween(begin: 0.85, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: widget.loading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: widget.size * 0.36,
                        height: widget.size * 0.36,
                        child: const CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(widget.playing),
                        size: widget.size * 0.52,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
