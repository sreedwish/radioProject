import 'package:flutter/material.dart';

/// Single-line text that is centred when it fits and scrolls
/// continuously, like a ticker, when it doesn't.
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  static const _gap = 56.0;
  static const _pixelsPerSecond = 40.0;

  late final _controller = AnimationController(vsync: this);

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scroll(double distance) {
    final duration = Duration(
      milliseconds: (distance / _pixelsPerSecond * 1000).round(),
    );
    if (_controller.duration == duration && _controller.isAnimating) return;
    _controller
      ..duration = duration
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final textWidth = painter.width;

        if (textWidth <= constraints.maxWidth) {
          _controller.stop();
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            textAlign: TextAlign.center,
          );
        }

        final distance = textWidth + _gap;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scroll(distance);
        });
        return ClipRect(
          child: SizedBox(
            height: painter.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-distance * _controller.value, 0),
                  child: child,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.text, style: style, maxLines: 1, softWrap: false),
                  const SizedBox(width: _gap),
                  Text(widget.text, style: style, maxLines: 1, softWrap: false),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
