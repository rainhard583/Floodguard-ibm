import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../models/weather_model.dart';

/// Scene cuaca hidup untuk kartu "Cuaca Saat Ini".
///
/// Sumber siang/malam menggunakan [Weather.isDay] dari WeatherAPI, bukan
/// menebak dari jam perangkat. Jadi saat API mengembalikan malam, scene akan
/// otomatis berubah menjadi bulan + awan + bintang. Saat siang, scene menjadi
/// matahari + awan. Efek animasi hanya dekoratif dan tidak mengubah data.
class WeatherIconAnimated extends StatelessWidget {
  final WeatherCondition condition;
  final bool isDay;
  final double size;

  const WeatherIconAnimated({
    super.key,
    required this.condition,
    this.isDay = true,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.65,
      height: size * 1.65,
      child: isDay ? _DayScene(condition: condition, size: size) : _NightScene(condition: condition, size: size),
    );
  }
}

class _DayScene extends StatelessWidget {
  final WeatherCondition condition;
  final double size;
  const _DayScene({required this.condition, required this.size});

  @override
  Widget build(BuildContext context) {
    final rainy = condition == WeatherCondition.hujanRingan || condition == WeatherCondition.hujanLebat || condition == WeatherCondition.badai;
    final cloudy = condition != WeatherCondition.cerah;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Glow matahari.
        Container(
          width: size * 1.18,
          height: size * 1.18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [const Color(0xFFFFD76A).withValues(alpha: .48), const Color(0xFFFFD76A).withValues(alpha: 0)]),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(.92, .92), end: const Offset(1.08, 1.08), duration: 1800.ms, curve: Curves.easeInOut),
        // Sinar matahari berputar pelan di belakang ikon — detail yang
        // bikin scene terasa lebih hidup/premium, bukan cuma ikon datar.
        Positioned(
          right: -size * .13,
          top: -size * .10,
          child: CustomPaint(
            size: Size(size * 1.4, size * 1.4),
            painter: _SunRaysPainter(color: const Color(0xFFFFC83D).withValues(alpha: .55)),
          ),
        ).animate(onPlay: (c) => c.repeat()).rotate(begin: 0, end: 1, duration: 22000.ms),
        // Matahari tetap terlihat saat siang, termasuk saat berawan.
        Positioned(
          right: size * .05,
          top: size * .03,
          child: Icon(Icons.wb_sunny_rounded, color: const Color(0xFFFFC83D), size: size * .92),
        ).animate(onPlay: (c) => c.repeat()).rotate(begin: 0, end: .12, duration: 5000.ms, curve: Curves.easeInOut),
        if (cloudy)
          Positioned(
            left: -size * .02,
            bottom: size * .05,
            child: _CloudCluster(size: size, dark: false),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: -3, end: 4, duration: 2600.ms, curve: Curves.easeInOut),
        if (!cloudy)
          Positioned(
            left: size * .08,
            bottom: size * .16,
            child: Icon(Icons.wb_sunny_rounded, color: const Color(0xFFFFB62B), size: size * 1.05),
          ),
        if (rainy)
          Positioned(left: size * .42, bottom: -size * .18, child: _RainDrops(size: size)),
      ],
    );
  }
}

class _NightScene extends StatelessWidget {
  final WeatherCondition condition;
  final double size;
  const _NightScene({required this.condition, required this.size});

  @override
  Widget build(BuildContext context) {
    final rainy = condition == WeatherCondition.hujanRingan || condition == WeatherCondition.hujanLebat || condition == WeatherCondition.badai;
    final cloudy = condition != WeatherCondition.cerah;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Bintang kecil berkelap-kelip.
        Positioned(left: size * .05, top: size * .10, child: const Icon(Icons.star_rounded, color: Color(0xFF9CCBFF), size: 7))
            .animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: .35, end: 1, duration: 1200.ms),
        Positioned(right: size * .18, top: size * .02, child: const Icon(Icons.star_rounded, color: Color(0xFFB9D9FF), size: 5))
            .animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: .2, end: .9, duration: 1500.ms),
        // Glow bulan.
        Container(
          width: size * 1.18,
          height: size * 1.18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [const Color(0xFFB9D8FF).withValues(alpha: .32), const Color(0xFFB9D8FF).withValues(alpha: 0)]),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(.94, .94), end: const Offset(1.07, 1.07), duration: 2200.ms, curve: Curves.easeInOut),
        // Crescent moon: lingkaran biru menutup sebagian lingkaran terang.
        Positioned(
          right: size * .08,
          top: size * .04,
          child: SizedBox(
            width: size * .88,
            height: size * .88,
            child: Stack(children: [
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFF4FAFF), shape: BoxShape.circle),
                child: SizedBox.expand(),
              ),
              Positioned(
                left: size * .18,
                top: -size * .02,
                child: Container(width: size * .82, height: size * .82, decoration: const BoxDecoration(color: Color(0xFFDCEEFF), shape: BoxShape.circle)),
              ),
            ]),
          ),
        ).animate(onPlay: (c) => c.repeat()).rotate(begin: -.02, end: .02, duration: 5000.ms, curve: Curves.easeInOut),
        if (cloudy)
          Positioned(
            left: -size * .02,
            bottom: size * .02,
            child: _CloudCluster(size: size, dark: true),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: -3, end: 4, duration: 2800.ms, curve: Curves.easeInOut),
        if (rainy)
          Positioned(left: size * .42, bottom: -size * .18, child: _RainDrops(size: size)),
      ],
    );
  }
}

class _CloudCluster extends StatelessWidget {
  final double size;
  final bool dark;
  const _CloudCluster({required this.size, required this.dark});

  @override
  Widget build(BuildContext context) {
    final base = dark ? const Color(0xFF9EB8D2) : Colors.white;
    final light = dark ? const Color(0xFFBED0E1) : const Color(0xFFF9FDFF);
    return SizedBox(
      width: size * 1.35,
      height: size * .90,
      child: Stack(children: [
        // Bayangan lembut di bawah gumpalan awan — bikin awannya terasa
        // punya kedalaman/mengambang, bukan cuma tempel datar di scene.
        Positioned(
          left: size * .12,
          bottom: 0,
          child: Container(
            width: size * 1.05,
            height: size * .16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(colors: [Colors.black.withValues(alpha: dark ? .14 : .08), Colors.black.withValues(alpha: 0)]),
            ),
          ),
        ),
        Positioned(left: 0, bottom: size * .17, child: Container(width: size * 1.18, height: size * .42, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(size)))),
        Positioned(left: size * .18, top: size * .25, child: Container(width: size * .60, height: size * .52, decoration: BoxDecoration(color: light, shape: BoxShape.circle))),
        Positioned(left: size * .54, top: size * .17, child: Container(width: size * .67, height: size * .60, decoration: BoxDecoration(color: light, shape: BoxShape.circle))),
        Positioned(left: size * .88, top: size * .35, child: Container(width: size * .40, height: size * .38, decoration: BoxDecoration(color: light, shape: BoxShape.circle))),
      ]),
    );
  }
}

class _SunRaysPainter extends CustomPainter {
  final Color color;
  const _SunRaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = radius * .07
      ..strokeCap = StrokeCap.round;

    // 8 sinar pendek memancar dari titik matahari — jaraknya (bukan
    // menempel di tepi ikon) supaya kelihatan seperti cahaya menyebar,
    // bukan cuma garis di sekeliling lingkaran.
    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final inner = Offset(center.dx + radius * .62 * math.cos(angle), center.dy + radius * .62 * math.sin(angle));
      final outer = Offset(center.dx + radius * .92 * math.cos(angle), center.dy + radius * .92 * math.sin(angle));
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunRaysPainter oldDelegate) => oldDelegate.color != color;
}

class _RainDrops extends StatelessWidget {
  final double size;
  const _RainDrops({required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: size * .045),
        child: Icon(Icons.water_drop_rounded, color: const Color(0xFF39A7FF), size: size * .22),
      );
    })).animate(onPlay: (c) => c.repeat()).moveY(begin: -2, end: 7, duration: 650.ms, curve: Curves.easeIn).fade(begin: .35, end: 1);
  }
}
