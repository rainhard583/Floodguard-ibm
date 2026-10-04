import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/map_layer_type.dart';
import '../../providers/map_layer_provider.dart';

class MapLayerButton extends ConsumerWidget {
  const MapLayerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherLayer = ref.watch(activeWeatherLayerProvider);
    final disasterLayer = ref.watch(activeDisasterLayerProvider);
    final panelOpen = ref.watch(mapLayerPanelVisibleProvider);
    final hasActiveLayer = weatherLayer != null || disasterLayer != null;

    return Material(
      color: panelOpen || hasActiveLayer ? AppColors.primary : Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ref.read(mapLayerPanelVisibleProvider.notifier).state = !panelOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            panelOpen ? Icons.close_rounded : Icons.layers_rounded,
            color: panelOpen || hasActiveLayer ? Colors.white : const Color(0xFF1A2733),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class MapDisasterButton extends ConsumerWidget {
  const MapDisasterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: const Color(0xFFF7F9FB),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          ref.read(mapLayerCategoryProvider.notifier).state = MapLayerCategory.disaster;
          ref.read(mapLayerPanelVisibleProvider.notifier).state = true;
        },
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Icon(Icons.add_rounded, color: Color(0xFF1A2733), size: 22),
        ),
      ),
    );
  }
}

/// Floating selector rendered on top of MapScreen. It intentionally does not
/// use Navigator/showModalBottomSheet, so changing layers is instantaneous.
class MapLayerSelectorPanel extends ConsumerStatefulWidget {
  final MapLayerCategory initialCategory;
  const MapLayerSelectorPanel({super.key, this.initialCategory = MapLayerCategory.weatherEnvironment});

  @override
  ConsumerState<MapLayerSelectorPanel> createState() => _MapLayerSelectorPanelState();
}

class _MapLayerSelectorPanelState extends ConsumerState<MapLayerSelectorPanel> {


  @override
  Widget build(BuildContext context) {
    final category = ref.watch(mapLayerCategoryProvider);
    return Material(
      elevation: 14,
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Layer Peta',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(mapLayerPanelVisibleProvider.notifier).state = false,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryChip(
                    label: '🌦️ Cuaca & Lingkungan',
                    selected: category == MapLayerCategory.weatherEnvironment,
                    onTap: () => ref.read(mapLayerCategoryProvider.notifier).state = MapLayerCategory.weatherEnvironment,
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: '🚨 Bencana Alam',
                    selected: category == MapLayerCategory.disaster,
                    onTap: () => ref.read(mapLayerCategoryProvider.notifier).state = MapLayerCategory.disaster,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: category == MapLayerCategory.weatherEnvironment
                  ? const _WeatherLayerGrid()
                  : const _DisasterLayerGrid(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.primary,
    backgroundColor: AppColors.surfaceElevated,
    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12),
  );
}

class _WeatherLayerGrid extends ConsumerWidget {
  const _WeatherLayerGrid();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWeatherLayerProvider);
    final entries = weatherLayerConfigs.entries.toList();
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.05,
      ),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final type = entries[index].key;
        final config = entries[index].value;
        return _LayerTile(
          config: config,
          selected: active == type,
          onTap: () {
            ref.read(activeDisasterLayerProvider.notifier).state = null;
            ref.read(activeWeatherLayerProvider.notifier).state = active == type ? null : type;
            ref.read(mapLayerPanelVisibleProvider.notifier).state = false;
          },
        );
      },
    );
  }
}

class _DisasterLayerGrid extends ConsumerWidget {
  const _DisasterLayerGrid();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDisasterLayerProvider);
    final entries = disasterLayerConfigs.entries.toList();
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.05,
      ),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final type = entries[index].key;
        final config = entries[index].value;
        return _LayerTile(
          config: config,
          selected: active == type,
          onTap: () {
            ref.read(activeWeatherLayerProvider.notifier).state = null;
            ref.read(activeDisasterLayerProvider.notifier).state = active == type ? null : type;
            ref.read(mapLayerPanelVisibleProvider.notifier).state = false;
          },
        );
      },
    );
  }
}

class _LayerTile extends StatefulWidget {
  final LayerConfig config;
  final bool selected;
  final VoidCallback onTap;
  const _LayerTile({required this.config, required this.selected, required this.onTap});

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final supported = widget.config.supported;
    final color = widget.config.legendColor;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: supported
          ? widget.onTap
          : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.config.title} belum tersedia.')),
              ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? color.withOpacity(.75) : Colors.transparent,
            width: selected ? 1.2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(.14), blurRadius: 10)]
              : const [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final scale = selected ? 1.0 + (_pulse.value * .07) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? color.withOpacity(.18) : Colors.white.withOpacity(.05),
                    ),
                    child: Icon(
                      widget.config.icon,
                      size: 19,
                      color: selected ? color : AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 5),
            Text(
              widget.config.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.8,
                height: 1.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (!supported)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Segera', style: TextStyle(fontSize: 7.5, color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}
