import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/weather_model.dart';
import '../states/app_error_view.dart';
import '../states/app_loading_view.dart';
import 'hourly_temp_chart.dart';
import 'weather_icon_animated.dart';

class WeatherSummaryCard extends StatelessWidget {
  final AsyncValue<Weather?> weather;
  final VoidCallback? onRetry;
  const WeatherSummaryCard({super.key, required this.weather, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF6C9ED4).withValues(alpha: .12), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: weather.when(
        loading: () => const SizedBox(height: 220, child: AppLoadingView()),
        error: (_, __) => SizedBox(height: 180, child: AppErrorView(message: 'Data cuaca belum tersedia.', onRetry: onRetry)),
        data: (data) => data == null
            ? const SizedBox(height: 120, child: Center(child: Text('Data cuaca belum tersedia.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
            : _WeatherContent(weather: data),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: .025, end: 0);
  }
}

class _WeatherContent extends StatelessWidget {
  final Weather weather;
  const _WeatherContent({required this.weather});

  @override
  Widget build(BuildContext context) {
    final conditionLabel = weather.isDay || weather.condition != WeatherCondition.cerah ? weather.condition.label : 'Cerah malam';
    final forecast = weather.forecast.take(24).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Cuaca Saat Ini', style: TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.4)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 14),
              const SizedBox(width: 5),
              Text(_observationAge(weather.updatedAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        _CurrentWeatherScene(weather: weather, conditionLabel: conditionLabel),
        const SizedBox(height: 10),
        _MetricsRow(weather: weather),
        if (forecast.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ramalan 24 Jam', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text('Prakiraan per jam dari WeatherAPI', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(999)), child: const Text('PRAKIRAAN', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .6))),
          ]),
          const SizedBox(height: 11),
          SizedBox(height: 136, child: ListView.separated(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: forecast.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) => _ForecastTile(item: forecast[index], index: index))),
          const SizedBox(height: 12),
          Container(
            height: 170,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 5),
            decoration: BoxDecoration(color: const Color(0xFFF8FBFF), borderRadius: BorderRadius.circular(23), border: Border.all(color: const Color(0xFFE8F0F8))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Row(children: [Icon(Icons.thermostat_rounded, color: AppColors.primary, size: 18), SizedBox(width: 6), Text('Grafik Suhu 24 Jam', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w900))])),
              const SizedBox(height: 3),
              Expanded(child: HourlyTempChart(items: forecast)),
            ]),
          ),
          const SizedBox(height: 10),
          _ForecastInfoRow(forecast: forecast),
        ],
      ]),
    );
  }
}

class _CurrentWeatherScene extends StatelessWidget {
  final Weather weather;
  final String conditionLabel;
  const _CurrentWeatherScene({required this.weather, required this.conditionLabel});

  @override
  Widget build(BuildContext context) {
    final day = weather.isDay;
    final gradient = day
        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE7F5FF), Color(0xFFBFE3FF), Color(0xFFF9FCFF)])
        : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEAF3FF), Color(0xFFC9DCF1), Color(0xFFF7FAFF)]);

    return Container(
      height: 190,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: day ? const Color(0xFFD5ECFF) : const Color(0xFFD6E3F1)),
      ),
      child: Stack(children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Colors.white.withValues(alpha: .08), Colors.white.withValues(alpha: .68)])))),
        Positioned(right: -10, top: 4, child: SizedBox(width: 160, height: 135, child: WeatherIconAnimated(condition: weather.condition, isDay: day, size: 72))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(color: day ? AppColors.primarySoft : const Color(0xFFE4EEFA), borderRadius: BorderRadius.circular(999)),
            child: Text(day ? 'SIANG' : 'MALAM', style: TextStyle(color: day ? AppColors.primary : const Color(0xFF486B96), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
          const Spacer(),
          Text('${weather.temperatureCelsius.round()}°', style: const TextStyle(color: AppColors.textPrimary, fontSize: 55, height: .9, fontWeight: FontWeight.w900, letterSpacing: -2.8)),
          const SizedBox(height: 4),
          Text(conditionLabel, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(weather.source, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final Weather weather;
  const _MetricsRow({required this.weather});

  @override
  Widget build(BuildContext context) {
    final extraTitle = weather.uvIndex != null ? 'UV' : (weather.pressureHpa != null ? 'Tekanan' : null);
    final extraValue = weather.uvIndex != null ? _uvLabel(weather.uvIndex!) : (weather.pressureHpa != null ? '${weather.pressureHpa!.round()} hPa' : null);
    final tiles = <Widget>[
      _MetricTile(icon: Icons.water_drop_outlined, title: 'Kelembapan', value: '${weather.humidityPercent.round()}%'),
      _MetricTile(icon: Icons.grain_rounded, title: 'Hujan', value: '${weather.rainfallMm.toStringAsFixed(1)} mm'),
      _MetricTile(icon: Icons.air_rounded, title: 'Angin', value: '${weather.windKph.round()} km/j'),
    ];
    if (extraTitle != null && extraValue != null) tiles.add(_MetricTile(icon: weather.uvIndex != null ? Icons.wb_sunny_outlined : Icons.speed_rounded, title: extraTitle, value: extraValue));

    return Row(children: [for (var i = 0; i < tiles.length; i++) ...[Expanded(child: tiles[i]), if (i != tiles.length - 1) const SizedBox(width: 7)]]);
  }

  String _uvLabel(double value) {
    if (value < 3) return 'Rendah';
    if (value < 6) return 'Sedang';
    if (value < 8) return 'Tinggi';
    if (value < 11) return 'Sangat tinggi';
    return 'Ekstrem';
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _MetricTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7EFF8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const Spacer(),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _ForecastTile extends StatelessWidget {
  final WeatherForecastItem item;
  final int index;
  const _ForecastTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final icon = item.condition == WeatherCondition.cerah && !item.isDay ? Icons.nightlight_round : item.condition.icon;
    final rain = item.precipitationMm > 0;
    return Container(
      width: 88,
      padding: const EdgeInsets.fromLTRB(7, 9, 7, 8),
      decoration: BoxDecoration(
        gradient: index == 0 ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE7F4FF), Colors.white]) : null,
        color: index == 0 ? null : const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: index == 0 ? AppColors.primary.withValues(alpha: .55) : const Color(0xFFE7EFF8), width: index == 0 ? 1.4 : 1),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(index == 0 ? 'Sekarang' : item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: index == 0 ? AppColors.primary : AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Icon(icon, color: AppColors.primary, size: 25),
        const SizedBox(height: 5),
        Text('${item.temperatureCelsius.round()}°', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(rain ? '${item.precipitationMm.toStringAsFixed(1)} mm' : '—', style: TextStyle(color: rain ? AppColors.primary : AppColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ForecastInfoRow extends StatelessWidget {
  final List<WeatherForecastItem> forecast;
  const _ForecastInfoRow({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final rainHours = forecast.where((e) => e.precipitationMm > 0).length;
    final maxTemp = forecast.map((e) => e.temperatureCelsius).reduce((a, b) => a > b ? a : b);
    final minTemp = forecast.map((e) => e.temperatureCelsius).reduce((a, b) => a < b ? a : b);
    return Row(children: [
      Expanded(child: _MiniForecastStat(label: 'Suhu maksimum', value: '${maxTemp.round()}°')),
      const SizedBox(width: 8),
      Expanded(child: _MiniForecastStat(label: 'Suhu minimum', value: '${minTemp.round()}°')),
      const SizedBox(width: 8),
      Expanded(child: _MiniForecastStat(label: 'Potensi hujan', value: '$rainHours jam')),
    ]);
  }
}

class _MiniForecastStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniForecastStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(10, 9, 10, 9), decoration: BoxDecoration(color: const Color(0xFFF8FBFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8F0F8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8.5, height: 1.1)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w900))]));
}

String _observationAge(DateTime value) {
  final age = DateTime.now().difference(value.toLocal());
  if (age.isNegative || age.inSeconds < 60) return 'Observasi baru saja';
  if (age.inMinutes < 60) return 'Observasi ${age.inMinutes} menit lalu';
  return 'Observasi ${age.inHours} jam lalu';
}
