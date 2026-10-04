import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/selected_location.dart';
import '../../providers/selected_earthquake_intensity_provider.dart';

class SelectedEarthquakeIntensityCard extends ConsumerWidget {
  final SelectedLocation location;
  const SelectedEarthquakeIntensityCard({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(selectedEarthquakeIntensityProvider(location));
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: state.when(
        loading: () => const _Loading(),
        error: (e, _) => const _Unavailable(),
        data: (q) {
          if (q == null) return const _Unavailable();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.location_on_rounded, color: Color(0xFF1769FF), size: 19),
                SizedBox(width: 8),
                Expanded(child: Text('Gempa di Wilayah Terpilih', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Text(q.magnitudeText, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                if (q.intensity != null)
                  Text(q.intensityText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text(q.place ?? 'Event tidak diketahui', style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
              const SizedBox(height: 3),
              Text(
                [
                  if (q.depthKm != null) 'Kedalaman ${q.depthKm!.toStringAsFixed(0)} km',
                  if (q.distanceKm != null) '±${q.distanceKm!.toStringAsFixed(0)} km dari titik pilihan',
                ].join(' • '),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                q.intensity == null
                    ? q.note
                    : '${q.intensityScale}: ${q.intensityText}${q.intensityScope == null ? '' : ' • ${q.intensityScope}'}',
                style: const TextStyle(fontSize: 10.5, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 5),
              Text('Sumber: ${q.source}', style: const TextStyle(fontSize: 9.5, color: Colors.black38)),
            ],
          );
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Row(children: [
    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.7)),
    SizedBox(width: 8),
    Text('Mengecek intensitas gempa di wilayah ini…', style: TextStyle(fontSize: 11, color: Colors.black54)),
  ]);
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) => const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(Icons.info_outline_rounded, size: 17, color: Colors.black45),
    SizedBox(width: 8),
    Expanded(child: Text('Belum ada event gempa yang dapat dipetakan ke wilayah ini dari sumber seismologi yang digunakan. FloodGuard tidak mengarang nilai intensitas.', style: TextStyle(fontSize: 10.5, color: Colors.black54, height: 1.4))),
  ]);
}
