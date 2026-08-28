import 'package:flutter/material.dart';

import '../theme.dart';

/// Draws a stylized, repeating PQRST waveform — the same shape used in the
/// design mockup. This is illustrative, not a render of the case's actual
/// signal: the app has no live signal data to plot yet (see EcgCase docs).
///
/// [showControls] adds a play/pause button and a scrub slider that sweep a
/// cursor across the trace over [durationSeconds] — purely a review aid
/// (matches how real ECG software lets you replay a strip), not tied to any
/// real playback of signal data.
class EcgTracePainter extends StatefulWidget {
  const EcgTracePainter({
    super.key,
    this.height = 110,
    this.showControls = false,
    this.durationSeconds = 10,
  });

  final double height;
  final bool showControls;
  final int durationSeconds;

  @override
  State<EcgTracePainter> createState() => _EcgTracePainterState();
}

class _EcgTracePainterState extends State<EcgTracePainter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.durationSeconds),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.isAnimating) {
      _controller.stop();
    } else {
      if (_controller.value >= 1) _controller.value = 0;
      _controller.forward();
    }
    setState(() {});
  }

  String _formatSeconds(double t) {
    final s = (t * widget.durationSeconds).round();
    return '00:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: widget.showControls
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _TracePainter(cursor: _controller.value),
                  ),
                )
              : CustomPaint(painter: const _TracePainter(cursor: null)),
        ),
        if (widget.showControls) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: _togglePlay,
                iconSize: 22,
                color: CardioLensColors.primary,
                icon: Icon(
                  _controller.isAnimating
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Text(
                  '${_formatSeconds(_controller.value)} / 00:${widget.durationSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: CardioLensColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Slider(
                    value: _controller.value.clamp(0, 1),
                    activeColor: CardioLensColors.primary,
                    inactiveColor: CardioLensColors.border,
                    onChanged: (v) {
                      _controller.stop();
                      _controller.value = v;
                      setState(() {});
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TracePainter extends CustomPainter {
  const _TracePainter({required this.cursor});

  /// Playback position, 0-1, or null to hide the cursor entirely.
  final double? cursor;

  static const _cycle = <Offset>[
    Offset(0, 0),
    Offset(10, 0),
    Offset(14, -6),
    Offset(20, -14),
    Offset(26, -6),
    Offset(30, 0),
    Offset(40, 0),
    Offset(44, 2),
    Offset(47, -62),
    Offset(50, 42),
    Offset(54, 0),
    Offset(70, -2),
    Offset(85, -22),
    Offset(95, -32),
    Offset(105, -22),
    Offset(115, 0),
    Offset(140, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CardioLensColors.primary
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final baselineY = size.height * 0.6;
    final scaleX = size.width / (3 * 140);
    final scaleY = size.height / 210;

    final path = Path();
    var first = true;
    for (var cycle = 0; cycle < 3; cycle++) {
      for (final point in _cycle) {
        final x = (cycle * 140 + point.dx) * scaleX;
        final y = baselineY + point.dy * scaleY;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(path, paint);

    if (cursor != null) {
      final cursorX = size.width * cursor!;
      final cursorPaint = Paint()
        ..color = CardioLensColors.alertAccent
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(cursorX, 0),
        Offset(cursorX, size.height),
        cursorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) =>
      oldDelegate.cursor != cursor;
}
