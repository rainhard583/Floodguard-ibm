import 'package:flutter/material.dart';
import '../../models/map_layer_type.dart';

class WeatherLegend extends StatelessWidget {
  final WeatherLayerType layer;
  const WeatherLegend({super.key, required this.layer});

  bool get _air => {
    WeatherLayerType.pm25,
    WeatherLayerType.pm10,
    WeatherLayerType.so2,
    WeatherLayerType.no2,
    WeatherLayerType.co,
    WeatherLayerType.ozone,
  }.contains(layer);

  @override
  Widget build(BuildContext context) {
    final cfg = weatherLayerConfigs[layer];
    final labels = _labels();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xE61B2A38),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(cfg?.title ?? 'Cuaca', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
            if (cfg?.unit != null) Text(cfg!.unit!, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [Color(0xFF2B83BA), Color(0xFF5EBD73), Color(0xFFFFE04B), Color(0xFFFF9F1C), Color(0xFFE53935)],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: labels.map((e) => Text(e, style: const TextStyle(color: Colors.white70, fontSize: 8.5))).toList()),
          if (layer == WeatherLayerType.wind || layer == WeatherLayerType.windGust)
            const Padding(padding: EdgeInsets.only(top: 5), child: Text('Warna = kecepatan · arus = arah angin', style: TextStyle(color: Colors.white70, fontSize: 9))),
          if (_air && layer == WeatherLayerType.so2)
            const Padding(padding: EdgeInsets.only(top: 5), child: Text('Merah = konsentrasi lebih tinggi', style: TextStyle(color: Colors.white70, fontSize: 9))),
        ],
      ),
    );
  }

  List<String> _labels() {
    switch (layer) {
      case WeatherLayerType.wind:
      case WeatherLayerType.windGust: return ['0', '10', '20', '40', '60+'];
      case WeatherLayerType.temperature: return ['<10', '20', '25', '30', '35+'];
      case WeatherLayerType.humidity: return ['0', '25', '50', '75', '100%'];
      case WeatherLayerType.pressure: return ['980', '1000', '1010', '1020', '1040+'];
      case WeatherLayerType.so2: return ['0', '10', '25', '40', '80+'];
      case WeatherLayerType.pm25: return ['0', '5', '15', '35', '75+'];
      case WeatherLayerType.pm10: return ['0', '20', '45', '100', '200+'];
      case WeatherLayerType.no2: return ['0', '10', '25', '50', '100+'];
      case WeatherLayerType.ozone: return ['0', '50', '100', '150', '200+'];
      case WeatherLayerType.co: return ['0', '1000', '4000', '8000', '12000+'];
      case WeatherLayerType.rain: return ['0', '1', '5', '10', '25+'];
      default: return ['Low', '', 'Medium', '', 'High'];
    }
  }
}
