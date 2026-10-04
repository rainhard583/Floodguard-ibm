import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/ai_analysis.dart';
import '../../models/hazard_analysis.dart';
import '../../providers/flood_point_risk_provider.dart';
import '../../models/selected_location.dart';
import '../../providers/ai_analyst_provider.dart';
import '../../providers/hazard_analysis_provider.dart';
import '../../providers/selected_location_provider.dart';
import '../../widgets/report/ai_analysis_card.dart';
import '../../widgets/report/data_source_footer.dart';
import '../../widgets/report/earthquake_live_card.dart';
import '../../widgets/report/hazard_result_card.dart';
import '../../widgets/report/location_context_card.dart';
import '../../widgets/report/realtime_hazard_summary_card.dart';
import '../../widgets/report/selected_earthquake_intensity_card.dart';
import '../../widgets/states/app_error_view.dart';

class DetectionScreen extends ConsumerStatefulWidget {
  const DetectionScreen({super.key});

  @override
  ConsumerState<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends ConsumerState<DetectionScreen> {
  SelectedLocation? _requested;
  HazardAnalysis? _completedAnalysis;
  final _questionController = TextEditingController();
  // PENTING — INI PERBAIKAN BUG DUPLIKASI REQUEST AI:
  //
  // Sebelumnya field ini `String _aiQuestion = ''` (String kosong, BUKAN
  // null). Karena `_results()` langsung membuat `AiAnstRequest` dan
  // memanggil `ref.watch(aiAnalystProvider(aiRequest))` TANPA syarat,
  // begitu hasil analisis bahaya selesai (`result` datang), Riverpod
  // otomatis mengeksekusi permintaan AI dengan `question: ''` — PADAHAL
  // user belum menekan tombol "Tanya AI" sama sekali. Lalu begitu user
  // benar-benar menekan tombol dan mengisi pertanyaan, `_aiQuestion`
  // berubah nilai -> `AiAnstRequest` baru (beda `question` = beda
  // identity di family provider) -> Riverpod mengeksekusi PERMINTAAN
  // KEDUA. Itulah sumber "dua request BMKG realtime hampir bersamaan"
  // di log.
  //
  // Perbaikannya: `null` = user BELUM pernah menekan "Tanya AI" sama
  // sekali, jadi `aiAnalystProvider` TIDAK PERNAH di-watch/dieksekusi
  // sampai user benar-benar menekan tombolnya — sekali itu saja.
  String? _aiQuestion;
  SelectedLocation? _aiLocationAtAsk;
  HazardAnalysis? _aiAnalysisAtAsk;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(selectedLocationProvider);
    final ai = _aiQuestion == null
        ? null
        : ref.watch(aiAnalystProvider(AiAnalystRequest(
            location: _aiLocationAtAsk,
            analysis: _aiAnalysisAtAsk,
            question: _aiQuestion!,
          )));

    if (_requested != null &&
        location != null &&
        (_requested!.latitude != location.latitude ||
            _requested!.longitude != location.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _requested = null;
          _completedAnalysis = null;
          _aiQuestion = null;
          _aiLocationAtAsk = null;
          _aiAnalysisAtAsk = null;
          _questionController.clear();
        });
      });
    }

    final analysis = _requested == null
        ? null
        : ref.watch(hazardAnalysisProvider(_requested!));

    final floodPoint = location == null
        ? null
        : ref.watch(floodPointRiskProvider(
            FloodPointRiskRequest(location.latitude, location.longitude),
          ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text('Lapor', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Analisis kondisi lokasi memakai data resmi terbaru yang tersedia.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            const EarthquakeLiveCard(),
            const SizedBox(height: 12),
            _AiQuestionBox(
              controller: _questionController,
              loading: ai?.isLoading ?? false,
              title: location == null ? 'Tanya AI tanpa memilih wilayah' : 'Tanya AI tentang lokasi / bencana',
              hint: location == null
                  ? 'Contoh: gempa terbaru sekarang berapa?'
                  : 'Contoh: apakah wilayah ini pernah banjir?',
              onAsk: () {
                final q = _questionController.text.trim();
                if (q.isEmpty) return;
                setState(() {
                  _aiQuestion = q;
                  _aiLocationAtAsk = location;
                  _aiAnalysisAtAsk = _completedAnalysis;
                });
              },
            ),
            if (ai != null) ...[
              const SizedBox(height: 10),
              ai.when(
                loading: () => const _AiLoadingCard(message: 'Mengambil data realtime terbaru...'),
                error: (error, _) => _AiErrorCard(
                  error: error,
                  onRetry: () {
                    ref.invalidate(aiAnalystProvider(AiAnalystRequest(
                      location: _aiLocationAtAsk,
                      analysis: _aiAnalysisAtAsk,
                      question: _aiQuestion!,
                    )));
                  },
                ),
                data: (answer) => AiAnalysisCard(result: answer),
              ),
            ],
            const SizedBox(height: 16),
            LocationContextCard(
              location: location,
              analyzing: analysis?.isLoading ?? false,
              onAnalyze: () {
                if (location == null) return;
                setState(() {
                  _requested = location;
                  _completedAnalysis = null;
                  _aiQuestion = null;
                  _aiLocationAtAsk = null;
                  _aiAnalysisAtAsk = null;
                  _questionController.clear();
                });
              },
              onOpenMap: () => context.go('/map'),
            ),
            if (floodPoint != null) ...[
              const SizedBox(height: 12),
              floodPoint.when(
                loading: () => const _FloodPointLoadingCard(),
                error: (error, _) => _FloodPointErrorCard(error: error),
                data: (result) => _FloodPointResultCard(result: result),
              ),
            ],
            if (location != null) ...[
              const SizedBox(height: 12),
              SelectedEarthquakeIntensityCard(location: location),
            ],
            if (analysis != null) ...[
              const SizedBox(height: 18),
              ...analysis.when(
                loading: () => [const _AnalyzingPlaceholder()],
                error: (error, _) => [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: AppErrorView(
                      icon: Icons.cloud_off_rounded,
                      message: 'Analisis tidak selesai. Coba lagi untuk mengambil data terbaru.',
                      onRetry: () => ref.invalidate(hazardAnalysisProvider(_requested!)),
                    ),
                  ),
                ],
                data: (result) {
                  _completedAnalysis = result;
                  return _results(result, ai);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _results(HazardAnalysis result, AsyncValue<AiAnalysisResult>? ai) {
    final location = _requested!;
    // Hanya buat AiAnalystRequest & watch provider-nya kalau user SUDAH
    // menekan "Tanya AI" minimal sekali (_aiQuestion != null). Sebelum
    // itu, `ai` sengaja `null` sehingga TIDAK ADA request AI yang jalan
    // otomatis hanya karena hasil analisis bahaya selesai dimuat.
    return [
      Row(
        children: [
          const Text('Hasil Analisis', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 18),
            tooltip: 'Ambil data terbaru',
            onPressed: () {
              setState(() {
                _completedAnalysis = null;
                _aiQuestion = null;
                _aiLocationAtAsk = null;
                _aiAnalysisAtAsk = null;
                _questionController.clear();
              });
              ref.invalidate(hazardAnalysisProvider(_requested!));
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      for (final hazard in result.hazards) HazardResultCard(result: hazard),
      if (ai != null)
        ai.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (answer) => answer.realtime == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RealtimeHazardSummaryCard(data: answer.realtime!),
                ),
        ),
      const SizedBox(height: 6),
      DataSourceFooter(sources: result.allSources, mlUsed: result.mlUsed),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: AppColors.riskWaspada, size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Indeks bahaya kawasan bukan peringatan dini. Data kejadian/peringatan terbaru tetap harus mengikuti BMKG, BNPB, dan Badan Geologi.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _FloodPointLoadingCard extends StatelessWidget {
  const _FloodPointLoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Expanded(child: Text('Memeriksa titik pada peta bahaya banjir BNPB...', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5))),
        ],
      ),
    );
  }
}

class _FloodPointErrorCard extends StatelessWidget {
  final Object error;
  const _FloodPointErrorCard({required this.error});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.riskWaspada, size: 18),
          const SizedBox(width: 9),
          Expanded(child: Text('Cek banjir belum berhasil: $error', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45))),
        ],
      ),
    );
  }
}

class _FloodPointResultCard extends StatelessWidget {
  final dynamic result;
  const _FloodPointResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final answer = result.answer?.toString() ?? 'BELUM DAPAT DITENTUKAN';
    final isYes = answer == 'YA';
    final isNo = answer == 'TIDAK';
    final label = isYes ? 'YA' : isNo ? 'TIDAK' : 'BELUM DAPAT DITENTUKAN';
    final icon = isYes ? Icons.flood_rounded : isNo ? Icons.verified_rounded : Icons.help_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.water_damage_rounded, color: AppColors.primary, size: 19),
              SizedBox(width: 8),
              Expanded(child: Text('Cek Banjir di Titik Ini', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, color: isYes ? AppColors.riskWaspada : AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 8),
          Text(result.explanation?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
          const SizedBox(height: 9),
          Text(
            'Sumber: ${result.source}${result.hazardClass != null ? ' • Bahaya ${result.hazardClass}' : ''}${result.riskClass != null ? ' • Risiko ${result.riskClass}' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Catatan: YA/TIDAK di sini berarti status titik pada peta bahaya banjir BNPB, bukan jaminan bahwa lokasi pasti/selalu tergenang atau bebas banjir saat kejadian tertentu.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AiQuestionBox extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onAsk;
  final String title;
  final String hint;
  const _AiQuestionBox({
    required this.controller,
    required this.loading,
    required this.onAsk,
    this.title = 'Tanya AI',
    this.hint = 'Contoh: bahaya apa yang paling perlu saya perhatikan?',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 17),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onAsk,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Tanya AI'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiLoadingCard extends StatelessWidget {
  final String message;
  const _AiLoadingCard({this.message = 'AI sedang membaca konteks lokasi dan data terbaru...'});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }
}

class _AiErrorCard extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const _AiErrorCard({required this.error, this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 9),
              Expanded(child: Text(error.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45))),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalyzingPlaceholder extends StatelessWidget {
  const _AnalyzingPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: const Column(
        children: [
          SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
          SizedBox(height: 14),
          Text('Mengambil data bahaya terbaru...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ],
      ),
    );
  }
}
