import '../models/volcano_model.dart';

/// Kontrak sumber data gunung api.
///
/// STATUS: PVMBG/MAGMA Indonesia BELUM punya endpoint publik resmi yang
/// stabil untuk diakses langsung dari aplikasi (per audit saat ini).
/// Implementasi asli (mis. `PvmbgVolcanoRepository`) baru bisa dibuat
/// begitu endpoint resmi/legal tersedia — lihat [DevMockVolcanoRepository]
/// untuk pengembangan UI sementara.
abstract class VolcanoRepository {
  Future<List<VolcanoModel>> getActiveVolcanoes();
}
