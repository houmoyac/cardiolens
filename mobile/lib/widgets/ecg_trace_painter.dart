import 'package:flutter/material.dart';

import '../theme.dart';

/// Draws a stylized, repeating PQRST waveform — the same shape used in the
/// design mockup. This is illustrative, not a render of the case's actual
/// signal: the app has no live signal data to plot yet (see EcgCase docs).
class EcgTracePainter extends StatelessWidget {
  const EcgTracePainter({super.key, this.height = 110});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TracePainter()),
    );
  }
}

class _TracePainter extends CustomPainter {
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
