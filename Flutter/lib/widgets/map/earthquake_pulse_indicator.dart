import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/disaster_risk_level.dart';

/// Indikator kecil dengan riak melingkar yang terus membesar & ikon
/// getaran yang sedikit "bergoyang" sendiri — dipakai di
/// [EarthquakeRiskCard] supaya risiko gempa tidak cuma tampil sebagai bar
/// statis.
///
/// Kecepatan riak & besar goyangan mengikuti [level] — makin tinggi
/// risikonya, makin cepat & makin besar goyangannya.
class EarthquakePulseIndicator extends StatefulWidget {
  final DisasterRiskLevel level;
  final double size;

  const EarthquakePulseIndicator({super.key, required this.level, this.size = 48});

  @override
  State<EarthquakePulseIndicator> createState() => _EarthquakePulseIndicatorState();
}

class _EarthquakePulseIndicatorState extends State<EarthquakePulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _speedFor(DisasterRiskLevel level) {
    return Duration(milliseconds: 2200 - (level.step * 260));
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _speedFor(widget.level))..repeat();
  }

  @override
  void didUpdateWidget(covariant EarthquakePulseIndicator oldWidget) {
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
    final color = widget.level.color;
    final shakeAmount = widget.level.step * 0.6;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              _ring(t: t, color: color),
              _ring(t: (t + 0.5) % 1.0, color: color),
              Transform.translate(
                offset: Offset(
                  math.sin(t * 4 * math.pi) * shakeAmount,
                  math.sin(t * 6 * math.pi) * shakeAmount * 0.6,
                ),
                child: Container(
                  width: widget.size * 0.55,
                  height: widget.size * 0.55,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.18)),
                  child: Icon(Icons.vibration_rounded, color: color, size: widget.size * 0.34),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring({required double t, required Color color}) {
    return Opacity(
      opacity: (1 - t).clamp(0.0, 1.0),
      child: Container(
        width: widget.size * (0.55 + t * 0.75),
        height: widget.size * (0.55 + t * 0.75),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.6)),
      ),
    );
  }
}
