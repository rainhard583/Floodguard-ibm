import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Floating disaster-guide handle shown only while a weather layer is active
/// and a location has been selected. It can be dragged anywhere on the map;
/// tapping it opens a compact guide with early signs and immediate actions.
class DisasterGuideHandle extends StatefulWidget {
  final bool visible;
  const DisasterGuideHandle({super.key, required this.visible});

  @override
  State<DisasterGuideHandle> createState() => _DisasterGuideHandleState();
}

class _DisasterGuideHandleState extends State<DisasterGuideHandle>
    with SingleTickerProviderStateMixin {
  static const _handleWidth = 54.0;
  static const _handleHeight = 76.0;
  static const _margin = 12.0;

  Offset _position = const Offset(_margin, 310);
  Offset _dragStart = Offset.zero;
  bool _dragging = false;
  bool _open = false;
  late final AnimationController _panelController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  bool get _opensToRight => _position.dx < MediaQuery.sizeOf(context).width / 2;

  @override
  void didUpdateWidget(covariant DisasterGuideHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && _open) {
      _open = false;
      _panelController.reverse();
    }
  }

  void _clampToScreen() {
    final size = MediaQuery.sizeOf(context);
    final topSafe = MediaQuery.paddingOf(context).top + 70;
    final bottomSafe = MediaQuery.paddingOf(context).bottom + 92;
    final maxX = (size.width - _handleWidth - _margin).clamp(_margin, size.width);
    final maxY = (size.height - _handleHeight - bottomSafe).clamp(topSafe, size.height);
    _position = Offset(
      _position.dx.clamp(_margin, maxX).toDouble(),
      _position.dy.clamp(topSafe, maxY).toDouble(),
    );
  }

  void _toggle() {
    if (_dragging) return;
    setState(() => _open = !_open);
    if (_open) {
      _clampToScreen();
      _panelController.forward();
    } else {
      _panelController.reverse();
    }
  }

  @override
  void dispose() {
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    _clampToScreen();

    final size = MediaQuery.sizeOf(context);
    final panelWidth = (size.width * .84).clamp(280.0, 360.0).toDouble();
    final panelLeft = _opensToRight
        ? _position.dx + _handleWidth + 8
        : _position.dx - panelWidth - 8;
    final safeLeft = panelLeft.clamp(8.0, size.width - panelWidth - 8).toDouble();
    final panelTop = (_position.dy - 26).clamp(
      MediaQuery.paddingOf(context).top + 58,
      size.height - 420,
    ).toDouble();

    return Stack(
      children: [
        if (_open)
          Positioned(
            left: safeLeft,
            top: panelTop,
            width: panelWidth,
            child: AnimatedBuilder(
              animation: _panelController,
              builder: (context, child) => Opacity(
                opacity: Curves.easeOut.transform(_panelController.value),
                child: Transform.translate(
                  offset: Offset(_opensToRight ? -18 * (1 - _panelController.value) : 18 * (1 - _panelController.value), 0),
                  child: Transform.scale(
                    alignment: _opensToRight ? Alignment.centerLeft : Alignment.centerRight,
                    scale: .97 + (.03 * _panelController.value),
                    child: child,
                  ),
                ),
              ),
              child: _GuidePanel(onClose: _toggle),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: (_) {
              _dragging = true;
              _dragStart = _position;
              if (_open) {
                setState(() => _open = false);
                _panelController.reverse();
              }
            },
            onPanUpdate: (details) {
              setState(() {
                _position = _dragStart + details.delta;
                _clampToScreen();
              });
            },
            onPanEnd: (_) {
              _dragging = false;
              _clampToScreen();
              setState(() {});
            },
            onTap: _toggle,
            child: _Handle(open: _open),
          ),
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  final bool open;
  const _Handle({required this.open});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 7,
      shadowColor: Colors.black.withOpacity(.25),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 54,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9E0E7)),
        ),
        child: Center(
          child: AnimatedRotation(
            turns: open ? .5 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: const Icon(Icons.chevron_left_rounded, size: 34, color: Color(0xFF15202B)),
          ),
        ),
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  final VoidCallback onClose;
  const _GuidePanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 18,
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 23),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Panduan Bencana', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Kenali tanda penting & tindakan aman', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                children: const [
                  _GuideSection(
                    icon: Icons.vibration_rounded,
                    title: 'Gempa bumi',
                    color: Color(0xFFFF7043),
                    note: 'Tidak ada tanda pasti yang dapat memprediksi gempa sebelum terjadi.',
                    bullets: [
                      'Saat terasa guncangan, lindungi kepala dan berlindung di bawah meja yang kokoh.',
                      'Jauhi kaca, lemari, dan benda yang mudah jatuh.',
                      'Setelah guncangan berhenti, keluar dengan tenang jika bangunan tidak aman.',
                    ],
                  ),
                  _GuideSection(
                    icon: Icons.tsunami_rounded,
                    title: 'Tsunami',
                    color: Color(0xFF29B6F6),
                    note: 'Waspadai terutama setelah gempa kuat atau lama di wilayah pesisir.',
                    bullets: [
                      'Gempa kuat/lama di dekat pantai dapat menjadi peringatan alami.',
                      'Air laut tiba-tiba surut atau naik tidak biasa dan terdengar suara gemuruh adalah tanda bahaya.',
                      'Segera menuju tempat tinggi/lebih jauh dari pantai; jangan menunggu sirene jika tanda alami sudah terlihat.',
                    ],
                  ),
                  _GuideSection(
                    icon: Icons.water_rounded,
                    title: 'Banjir',
                    color: Color(0xFF42A5F5),
                    note: 'Perhatikan kenaikan air dan informasi resmi setempat.',
                    bullets: [
                      'Pindahkan diri dan barang penting ke tempat yang lebih tinggi jika air terus naik.',
                      'Hindari arus deras dan jangan menerobos genangan yang tidak diketahui kedalamannya.',
                    ],
                  ),
                  _GuideSection(
                    icon: Icons.terrain_rounded,
                    title: 'Gunung api',
                    color: Color(0xFFEF5350),
                    note: 'Ikuti status dan rekomendasi resmi PVMBG/BPBD.',
                    bullets: [
                      'Waspadai abu vulkanik, perubahan aktivitas, dan instruksi evakuasi resmi.',
                      'Gunakan masker/kacamata saat abu turun dan jauhi zona bahaya.',
                    ],
                  ),
                  _GuideSection(
                    icon: Icons.air_rounded,
                    title: 'Udara buruk / abu',
                    color: Color(0xFFFFB74D),
                    note: 'Data kualitas udara di peta adalah model/forecast, bukan pengukuran sensor lokal.',
                    bullets: [
                      'Jika udara berdebu/asap, kurangi aktivitas luar dan gunakan masker yang sesuai.',
                      'Untuk keadaan darurat, ikuti informasi resmi pemerintah/instansi kebencanaan.',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String note;
  final List<String> bullets;
  const _GuideSection({required this.icon, required this.title, required this.color, required this.note, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 9),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 7),
          Text(note, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.35)),
          const SizedBox(height: 5),
          ...bullets.map((text) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 5, color: AppColors.textSecondary)),
                    const SizedBox(width: 7),
                    Expanded(child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10.8, height: 1.35))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
