import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/weather_model.dart';

/// Grafik suhu forecast yang ringan dan modern.
class HourlyTempChart extends StatelessWidget {
  final List<WeatherForecastItem> items;

  const HourlyTempChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 88,
      width: double.infinity,
      child: CustomPaint(
        painter: _TempLinePainter(
          temps: items.map((e) => e.temperatureCelsius).toList(),
        ),
      ),
    );
  }
}

class _TempLinePainter extends CustomPainter {
  final List<double> temps;

  _TempLinePainter({required this.temps});

  @override
  void paint(Canvas canvas, Size size) {
    if (temps.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minTemp = temps.reduce(math.min) - 1;
    final maxTemp = temps.reduce(math.max) + 1;
    final range = math.max(maxTemp - minTemp, 1.0);
    final dx = size.width / (temps.length - 1);

    final points = List.generate(temps.length, (i) {
      final normalized = (temps[i] - minTemp) / range;
      return Offset(dx * i, size.height - (normalized * (size.height - 16)) - 8);
    });

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()..color = AppColors.primary.withValues(alpha: 0.10),
    );
    canvas.drawPath(path, linePaint);

    // Titik forecast dibuat kecil agar grafik tidak terlihat ramai.
    final pointPaint = Paint()..color = AppColors.primary;
    for (final point in points) {
      canvas.drawCircle(point, 3.2, pointPaint);
      canvas.drawCircle(
        point,
        1.35,
        Paint()..color = AppColors.surfaceElevated,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TempLinePainter oldDelegate) {
    if (oldDelegate.temps.length != temps.length) return true;
    for (var i = 0; i < temps.length; i++) {
      if (oldDelegate.temps[i] != temps[i]) return true;
    }
    return false;
  }
}
