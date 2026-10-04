import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/searched_place_model.dart';
import '../../providers/location_search_provider.dart';

/// Kolom pencarian lokasi global di atas Peta. Pencarian dipicu saat user
/// menekan tombol cari / submit (BUKAN tiap huruf diketik) supaya tidak
/// membanjiri Nominatim dengan request (lihat catatan kebijakan di
/// [NominatimLocationSearchRepository]).
class LocationSearchBar extends ConsumerStatefulWidget {
  final ValueChanged<SearchedPlace> onPlaceSelected;

  const LocationSearchBar({super.key, required this.onPlaceSelected});

  @override
  ConsumerState<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends ConsumerState<LocationSearchBar> {
  final _controller = TextEditingController();
  List<SearchedPlace> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(locationSearchRepositoryProvider);
      final results = await repository.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mencari lokasi. Periksa koneksi internet Anda.';
        _loading = false;
      });
    }
  }

  void _selectPlace(SearchedPlace place) {
    // PENTING (bug fix): sebelumnya field ini diisi nama lokasi yang
    // dipilih (`_controller.text = place.displayName`). Nama dari
    // Nominatim sering panjang (mis. "Jatimakmur, Bekasi, Jawa Barat,
    // 17413, Indonesia"), dan kalau user langsung mengetik pencarian
    // BARU tanpa menghapus teks itu dulu, ketikannya numpuk di
    // belakangnya (mis. jadi "...IndonesiaBekasi") — jadi query-nya jadi
    // tidak masuk akal dan Nominatim tidak mengembalikan hasil apa pun.
    // Itu sebabnya search kelihatan "tidak bisa dipakai lagi" setelah
    // sekali pilih lokasi. Fix: kosongkan field-nya, siap untuk
    // pencarian baru yang bersih.
    setState(() {
      _results = [];
      _controller.clear();
    });
    widget.onPlaceSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    // Sengaja kartu TERANG (bukan gelap seperti tema app) — supaya kolom
    // cari ini SELALU jelas kelihatan di atas peta apa pun (peta gelap
    // saat tile belum termuat, peta terang, dsb.), sama seperti kolom
    // cari di aplikasi peta pada umumnya (Google Maps, dst).
    const cardColor = Colors.white;
    const textColor = Color(0xFF1A2733);
    const hintColor = Color(0xFF7A8896);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: const TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari lokasi mana saja...',
              hintStyle: const TextStyle(color: hintColor, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                      onPressed: _search,
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.riskBahaya, fontSize: 12.5)),
            ),
          ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x14000000)),
              itemBuilder: (context, index) {
                final place = _results[index];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
                    title: Text(
                      place.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textColor, fontSize: 13),
                    ),
                    onTap: () => _selectPlace(place),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
