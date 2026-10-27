import 'package:flutter/material.dart';

/// Whether to lay screens out side by side: whenever the window or screen is
/// wider than it is tall, which includes a desktop browser window.
bool useLandscapeLayout(BuildContext context) =>
    MediaQuery.orientationOf(context) == Orientation.landscape;

/// Keeps the portrait layout a phone-sized column on wide screens.
class PortraitColumn extends StatelessWidget {
  const PortraitColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => useLandscapeLayout(context)
      ? child
      : Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        );
}

/// Lays [child] out in the space under the area the
/// background artwork used to reserve for its wordmark, scaling
/// it down if the screen is short.
class BelowLogo extends StatelessWidget {
  const BelowLogo({super.key, required this.child});

  final Widget child;

  /// Share of the screen height the artwork's block starts at.
  static const _clearance = 0.36;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // The top bar above this sits about this far down the screen.
      final top = MediaQuery.paddingOf(context).top + 72;
      // Side-by-side landscape layouts have the room, so just centre.
      if (useLandscapeLayout(context)) {
        return FitPane(child: child);
      }
      final inset = (MediaQuery.sizeOf(context).height * _clearance - top)
          .clamp(0.0, c.maxHeight * 0.8);
      return Padding(
        padding: EdgeInsets.only(top: inset),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(width: c.maxWidth, child: child),
        ),
      );
    },
  );
}

/// Centres [child] in its pane, scaling it down rather than overflowing when
/// the pane is short (phones in landscape).
class FitPane extends StatelessWidget {
  const FitPane({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: c.maxWidth, child: child),
      ),
    ),
  );
}

/// The artwork behind the screens: the wide one in landscape, the tall one in
/// portrait.
DecorationImage orientedBackground(BuildContext context) => DecorationImage(
  image: AssetImage(
    MediaQuery.orientationOf(context) == Orientation.landscape
        ? 'assets/images/background_web.png'
        : 'assets/images/background.png',
  ),
  fit: BoxFit.cover,
);
