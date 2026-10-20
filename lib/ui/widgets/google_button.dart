import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Google's "G", drawn rather than shipped as an image so it stays sharp
/// at any size.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GPainter());
}

class _GPainter extends CustomPainter {
  const _GPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final c = Offset(s / 2, s / 2);
    final rect = Rect.fromCircle(center: c, radius: (s - stroke) / 2);
    double deg(double d) => d * math.pi / 180;
    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Clockwise from three o'clock; the opening is at the upper right.
    canvas.drawArc(rect, deg(0), deg(46), false, arc(_blue));
    canvas.drawArc(rect, deg(45), deg(91), false, arc(_green));
    canvas.drawArc(rect, deg(135), deg(91), false, arc(_yellow));
    canvas.drawArc(rect, deg(225), deg(95), false, arc(_red));
    // The bar, from the middle out to the right edge.
    canvas.drawRect(
      Rect.fromLTRB(s / 2, s / 2 - stroke / 2, s, s / 2 + stroke / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GPainter oldDelegate) => false;
}

/// "Continue with Google", in Google's own button style: white with a grey
/// outline in light mode, near black in dark mode.
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const GoogleButton({super.key, required this.onPressed, this.label = 'Continue with Google'});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: dark ? const Color(0xFF131314) : Colors.white,
        foregroundColor: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
        side: BorderSide(color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775)),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GoogleLogo(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
