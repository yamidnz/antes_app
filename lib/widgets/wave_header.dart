import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// La franja de "sismógrafo en vivo" que corona la app. En reposo es una
/// línea casi plana con ligero ruido; en modo alerta se convierte en una
/// onda creciente. Es el elemento de marca distintivo de ANTES.
class WaveHeader extends StatefulWidget {
  final bool alertMode;
  const WaveHeader({super.key, this.alertMode = false});

  @override
  State<WaveHeader> createState() => _WaveHeaderState();
}

class _WaveHeaderState extends State<WaveHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _points = List.filled(80, 0);
  final _rand = Random();
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 60))
      ..addListener(_tick)
      ..repeat();
  }

  void _tick() {
    double v;
    if (widget.alertMode) {
      _t += 0.5;
      v = sin(_t) * 26 * min(1, _t / 3) + (_rand.nextDouble() - 0.5) * 6;
    } else {
      v = (_rand.nextDouble() - 0.5) * 4;
    }
    setState(() {
      _points.add(v);
      _points.removeAt(0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: _WavePainter(_points, widget.alertMode ? AppColors.red : AppColors.teal),
        size: Size.infinite,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _WavePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path();
    final step = size.width / points.length;
    final mid = size.height / 2;
    for (var i = 0; i < points.length; i++) {
      final x = i * step;
      final y = mid - points[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}
