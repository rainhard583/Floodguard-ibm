import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/bmkg_latest_earthquake_provider.dart';
import '../../providers/usgs_latest_earthquake_provider.dart';

class EarthquakeLiveCard extends ConsumerWidget {
  const EarthquakeLiveCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bmkg = ref.watch(bmkgLatestEarthquakeProvider);
    final usgs = ref.watch(usgsLatestEarthquakeProvider);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public_rounded, color: Color(0xFF1769FF), size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gempa Live / Near-Real-Time',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Text('±1 menit', style: TextStyle(fontSize: 10, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 10),
          _bmkg(bmkg),
          const Divider(height: 20),
          _usgs(usgs),
          const SizedBox(height: 8),
          const Text(
            'BMKG = Indonesia • USGS = global. Data kejadian, bukan prediksi. Parameter awal dapat direvisi oleh lembaga seismologi.',
            style: TextStyle(fontSize: 9.5, color: Colors.black45, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _bmkg(AsyncValue<dynamic> state) {
    if (state.hasError) return const _ErrorLine(label: 'Indonesia • BMKG');
    final q = state.valueOrNull;
    if (q == null) {
      return const _LoadingLine(label: 'Indonesia • BMKG');
    }
    final felt = (q.felt ?? '').toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('INDONESIA • BMKG', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(q.displayMagnitude, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          '${q.region ?? 'Lokasi tidak tersedia'} • ${q.depth ?? '-'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Colors.black87),
        ),
        if (felt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('Intensitas: MMI $felt', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
      ],
    );
  }

  Widget _usgs(AsyncValue<dynamic> state) {
    if (state.hasError) return const _ErrorLine(label: 'GLOBAL • USGS');
    final q = state.valueOrNull;
    if (q == null) {
      return const _LoadingLine(label: 'GLOBAL • USGS');
    }
    final mmi = q.mmi == null ? '' : ' • MMI ${q.mmi!.toStringAsFixed(1)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GLOBAL • USGS', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('M${q.magnitude.toStringAsFixed(1)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          '${q.place} • ${q.depthKm.toStringAsFixed(1)} km$mmi',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Colors.black87),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String label;
  const _ErrorLine({required this.label});
  @override Widget build(BuildContext context) => Row(children: [const Icon(Icons.cloud_off_rounded,size:15,color:Colors.orange), const SizedBox(width:8), Expanded(child: Text('$label • data belum tersedia', style: const TextStyle(fontSize:11,color:Colors.black54)))]);
}

class _LoadingLine extends StatelessWidget {
  final String label;
  const _LoadingLine({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.7)),
        const SizedBox(width: 8),
        Text('$label • memuat data…', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}
