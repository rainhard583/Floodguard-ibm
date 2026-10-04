import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../services/earthquake_alert_service.dart';

/// Shell navigasi FloodGuard.
/// Dock putih dibuat solid (tanpa BackdropFilter dan tanpa shadow ke area Home)
/// supaya tidak muncul area abu-abu/berkabut di atas navigasi.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Beranda'),
    _NavItem(icon: Icons.map_rounded, label: 'Peta'),
    _NavItem(icon: Icons.camera_alt_rounded, label: 'Lapor'),
    _NavItem(icon: Icons.history_rounded, label: 'Riwayat'),
    _NavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  // Tinggi dock dikecilkan dari 88 -> 74 (dan semua ukuran turunannya di
  // bawah ikut diskalakan proporsional) sesuai permintaan "agak gede".
  static const double _dockHeight = 74;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider).valueOrNull;
    EarthquakeAlertService.instance.start();
    if (location != null) {
      EarthquakeAlertService.instance.updateLocation(location);
    }

    final selected = navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: _dockHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // PENTING: tidak ada blur dan tidak ada shadow yang menyebar
              // ke area Home. Di luar path benar-benar transparan.
              Positioned.fill(
                child: ClipPath(
                  clipper: _CleanCurvedDockClipper(),
                  clipBehavior: Clip.antiAlias,
                  child: const ColoredBox(color: Colors.white),
                ),
              ),

              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final isSelected = index == selected;
                    final isCenter = index == 2;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => navigationShell.goBranch(
                          index,
                          initialLocation: index == navigationShell.currentIndex,
                        ),
                        child: SizedBox(
                          height: _dockHeight,
                          child: isCenter
                              ? Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: -36,
                                      child: Center(
                                        child: _CenterNavButton(
                                          icon: item.icon,
                                          active: isSelected,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 25,
                                      child: Text(
                                        item.label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _SideNavIcon(
                                      icon: item.icon,
                                      selected: isSelected,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kurva tipis: bagian putih mulai rendah di kiri/kanan,
/// turun sedikit di tengah untuk memberi ruang tombol Lapor.
/// Tidak membuat bayangan/blur sehingga tidak mengotori area Home.
///
/// Nilai-nilai titik kurva diskalakan proporsional (×0.84) mengikuti
/// pengecilan tinggi dock dari 88 -> 74, supaya bentuk lengkungnya tetap
/// sama persis, cuma lebih ringkas.
class _CleanCurvedDockClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, 23);

    path.cubicTo(
      size.width * .17,
      18,
      size.width * .31,
      18,
      size.width * .41,
      26,
    );
    path.cubicTo(
      size.width * .46,
      30,
      size.width * .48,
      37,
      size.width * .50,
      39,
    );
    path.cubicTo(
      size.width * .52,
      37,
      size.width * .54,
      30,
      size.width * .59,
      26,
    );
    path.cubicTo(
      size.width * .69,
      18,
      size.width * .83,
      18,
      size.width,
      23,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _CleanCurvedDockClipper oldClipper) => false;
}

/// Ikon tab samping (bukan Lapor) — animasi "pop" halus setiap kali
/// jadi/berhenti aktif, memakai flutter_animate `target` (0/1) supaya
/// otomatis replay setiap kali [selected] berubah, tanpa perlu
/// AnimationController manual.
class _SideNavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _SideNavIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: selected ? 40 : 36,
      height: selected ? 40 : 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFFE7F3FF) : Colors.transparent,
      ),
      child: Icon(
        icon,
        size: selected ? 21 : 20,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
    )
        .animate(target: selected ? 1 : 0)
        .scaleXY(begin: 1, end: 1.12, duration: 260.ms, curve: Curves.easeOutBack)
        .then(delay: 0.ms)
        .scaleXY(begin: 1.12, end: 1, duration: 160.ms, curve: Curves.easeIn);
  }
}

class _CenterNavButton extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _CenterNavButton({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow yang "bernapas" pelan di belakang tombol Lapor, hanya
          // saat tab ini aktif — sinyal visual halus bahwa fitur kamera
          // ini yang sedang dipakai.
          if (active)
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: .16),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.22, duration: 1100.ms, curve: Curves.easeInOut)
                .fadeOut(begin: 1, duration: 1100.ms, curve: Curves.easeInOut),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: .10),
                width: 1,
              ),
              // Shadow hanya di bawah tombol, bukan di area Home.
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .14),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEAF5FF),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
              .animate(target: active ? 1 : 0)
              .scaleXY(begin: 1, end: 1.08, duration: 220.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
