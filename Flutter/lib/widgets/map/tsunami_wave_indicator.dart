import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/disaster_risk_level.dart';

/// Indikator kecil berbentuk "tangki" berisi air yang bergerak SENDIRI
/// (gelombang looping terus-menerus), dipakai di [TsunamiRiskCard] supaya
/// risiko tsunami tidak cuma tampil sebagai bar statis.
///
/// Tinggi air & kecepatan gelombang mengikuti [level] — makin tinggi
/// risikonya, makin tinggi permukaan airnya & makin cepat gelombangnya.
class TsunamiWaveIndicator extends StatefulWidget {
  final DisasterRiskLevel level;
  final double size;

  const TsunamiWaveIndicator({super.key, required this.level, this.size = 48});

  @override
  State<TsunamiWaveIndicator> createState() => _TsunamiWaveIndicatorState();
}

class _TsunamiWaveIndicatorState extends State<TsunamiWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _speedFor(DisasterRiskLevel level) {
    return Duration(milliseconds: 2600 - (level.step * 300));
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _speedFor(widget.level))..repeat();
  }

  @override
  void didUpdateWidget(covariant TsunamiWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _controller.duration = _speedFor(widget.level);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.32),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: widget.level.color.withOpacity(0.15),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _WavePainter(
                progress: _controller.value,
                fillLevel: widget.level.step / 5,
                color: widget.level.color,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress; // 0..1 — dipakai untuk menggeser fase gelombang.
  final double fillLevel; // 0..1 — tinggi air.
  final Color color;

  _WavePainter({required this.progress, required this.fillLevel, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final waterTop = size.height * (1 - fillLevel.clamp(0.15, 1.0));
    final waveHeight = size.height * 0.07;
    final phase = progress * 2 * math.pi;

    void drawLayer(double phaseShift, double verticalOffset, Color layerColor) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x++) {
        final y = waterTop +
            verticalOffset +
            math.sin((x / size.width * 2 * math.pi) + phase + phaseShift) * waveHeight;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, Paint()..color = layerColor);
    }

    // Dua lapis gelombang sedikit beda fase & warna supaya terasa seperti
    // air sungguhan, bukan cuma satu garis sinus datar.
    drawLayer(math.pi / 2, -waveHeight * 0.5, color.withOpacity(0.45));
    drawLayer(0, 0, color.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fillLevel != fillLevel ||
      oldDelegate.color != color;
}
