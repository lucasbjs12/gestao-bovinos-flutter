import 'package:flutter/material.dart';

void drawMarca(Canvas canvas, Size size, Color color) {
  final p = Paint()..color = color..style = PaintingStyle.fill;
  final sx = size.width / 24;
  final sy = size.height / 24;
  double x(double v) => v * sx;
  double y(double v) => v * sy;
  final path = Path()
    ..moveTo(x(6), y(3))..lineTo(x(3), y(3))..lineTo(x(3), y(6))
    ..cubicTo(x(4.66), y(6), x(6), y(4.66), x(6), y(3))..close()
    ..moveTo(x(10), y(3))..lineTo(x(8), y(3))
    ..cubicTo(x(8), y(5.76), x(5.76), y(8), x(3), y(8))
    ..lineTo(x(3), y(10))..cubicTo(x(6.87), y(10), x(10), y(6.87), x(10), y(3))..close()
    ..moveTo(x(14), y(3))..lineTo(x(12), y(3))
    ..cubicTo(x(12), y(7.97), x(7.97), y(12), x(3), y(12))
    ..lineTo(x(3), y(14))..cubicTo(x(9.08), y(14), x(14), y(9.07), x(14), y(3))..close()
    ..moveTo(x(10), y(21))..lineTo(x(12), y(21))
    ..cubicTo(x(12), y(16.03), x(16.03), y(12), x(21), y(12))
    ..lineTo(x(21), y(10))..cubicTo(x(14.93), y(10), x(10), y(14.93), x(10), y(21))..close()
    ..moveTo(x(18), y(21))..lineTo(x(21), y(21))..lineTo(x(21), y(18))
    ..cubicTo(x(19.34), y(18), x(18), y(19.34), x(18), y(21))..close()
    ..moveTo(x(14), y(21))..lineTo(x(16), y(21))
    ..cubicTo(x(16), y(18.24), x(18.24), y(16), x(21), y(16))
    ..lineTo(x(21), y(14))..cubicTo(x(17.13), y(14), x(14), y(17.13), x(14), y(21))..close();
  canvas.drawPath(path, p);
}

class MarcaPainter extends CustomPainter {
  final Color color;
  const MarcaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) => drawMarca(canvas, size, color);

  @override
  bool shouldRepaint(MarcaPainter o) => o.color != color;
}
