import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/layer_sample_point.dart';
import '../../models/map_layer_type.dart';

/// Lightweight continuous weather field. The API samples are hidden data;
/// the user only sees one smooth geographic surface.
class WeatherFieldOverlay extends StatefulWidget {
  final WeatherLayerType layer;
  final List<LayerSamplePoint> samples;
  final double opacity;

  const WeatherFieldOverlay({
    super.key,
    required this.layer,
    required this.samples,
    this.opacity = .62,
  });

  @override
  State<WeatherFieldOverlay> createState() => _WeatherFieldOverlayState();
}

class _WeatherFieldOverlayState extends State<WeatherFieldOverlay> {
  _RasterResult? _raster;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant WeatherFieldOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer != widget.layer || !_same(oldWidget.samples, widget.samples)) {
      _rebuild();
    }
  }

  bool _same(List<LayerSamplePoint> a, List<LayerSamplePoint> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.point != y.point ||
          x.value != y.value ||
          x.u != y.u ||
          x.v != y.v ||
          x.updatedAt != y.updatedAt) return false;
    }
    return true;
  }

  void _rebuild() {
    final generation = ++_generation;
    final samples = List<LayerSamplePoint>.of(widget.samples);
    if (samples.length < 4) {
      if (mounted) setState(() => _raster = null);
      return;
    }
    _buildRaster(widget.layer, samples).then((r) {
      if (!mounted || generation != _generation) return;
      setState(() => _raster = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _raster;
    if (r == null) return const SizedBox.shrink();
    return OverlayImageLayer(
      key: const ValueKey('weather_field_layer'),
      overlayImages: [
        OverlayImage(
          imageProvider: MemoryImage(r.bytes),
          bounds: r.bounds,
          opacity: widget.opacity,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ],
    );
  }
}

class _RasterResult {
  final Uint8List bytes;
  final LatLngBounds bounds;
  const _RasterResult(this.bytes, this.bounds);
}

Future<_RasterResult?> _buildRaster(
  WeatherLayerType layer,
  List<LayerSamplePoint> samples,
) async {
  final grid = _GridData.from(samples);
  if (grid == null) return null;

  // Small texture + GPU scaling = smooth field without a CPU-heavy painter.
  const size = 128;
  final pixels = Uint8List(size * size * 4);
  final values = grid.samples.map((s) => s.value).where((v) => v.isFinite).toList();
  if (values.isEmpty) return null;
  values.sort();
  final isPollutant = {WeatherLayerType.airQuality, WeatherLayerType.pm25, WeatherLayerType.pm10, WeatherLayerType.so2, WeatherLayerType.no2, WeatherLayerType.co, WeatherLayerType.ozone}.contains(layer);
  // Pollutant fields use absolute scales. Dynamic min/max made a single
  // outlier turn into a giant red blob and falsely suggested danger.
  final minValue = isPollutant ? 0.0 : values.first;
  final maxValue = isPollutant ? _pollutantMax(layer) : values.last;

  for (var y = 0; y < size; y++) {
    final fy = (size == 1) ? 0.0 : y / (size - 1);
    for (var x = 0; x < size; x++) {
      final fx = (size == 1) ? 0.0 : x / (size - 1);
      final value = grid.valueAtNormalized(fx, fy);
      final c = _colorFor(layer, value, minValue: minValue, maxValue: maxValue);
      final i = (y * size + x) * 4;
      pixels[i] = c.red;
      pixels[i + 1] = c.green;
      pixels[i + 2] = c.blue;
      pixels[i + 3] = c.alpha;
    }
  }

  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: size,
    height: size,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  frame.image.dispose();

  final bytes = data?.buffer.asUint8List();
  if (bytes == null) return null;
  return _RasterResult(
    Uint8List.fromList(bytes),
    LatLngBounds(
      LatLng(grid.maxLat, grid.minLng),
      LatLng(grid.minLat, grid.maxLng),
    ),
  );
}

class _GridData {
  final int n;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final List<LayerSamplePoint> samples;

  const _GridData({
    required this.n,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.samples,
  });

  static _GridData? from(List<LayerSamplePoint> samples) {
    if (samples.length < 4) return null;

    // The API may omit a coordinate whose value is temporarily unavailable.
    // Do not throw the whole field away just because the response is no
    // longer a perfect NxN list. Reconstruct the regular geographic grid
    // from the coordinates and fill only missing cells from the nearest real
    // sample. The user still sees a continuous field, never sample markers.
    final latKeys = <String, double>{};
    final lngKeys = <String, double>{};
    for (final s in samples) {
      latKeys[s.point.latitude.toStringAsFixed(5)] = s.point.latitude;
      lngKeys[s.point.longitude.toStringAsFixed(5)] = s.point.longitude;
    }
    final lats = latKeys.values.toList()..sort();
    final lngs = lngKeys.values.toList()..sort();
    if (lats.length < 2 || lngs.length < 2) return null;

    final nLat = lats.length;
    final nLng = lngs.length;
    final byCell = <String, LayerSamplePoint>{};
    String key(int r, int c) => '$r:$c';
    int nearestIndex(List<double> values, double value) {
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < values.length; i++) {
        final d = (values[i] - value).abs();
        if (d < bestD) { bestD = d; best = i; }
      }
      return best;
    }
    for (final s in samples) {
      final r = nearestIndex(lats, s.point.latitude);
      final c = nearestIndex(lngs, s.point.longitude);
      byCell[key(r, c)] = s;
    }

    final complete = <LayerSamplePoint>[];
    for (var r = 0; r < nLat; r++) {
      for (var c = 0; c < nLng; c++) {
        final existing = byCell[key(r, c)];
        if (existing != null) {
          complete.add(existing);
          continue;
        }
        LayerSamplePoint? nearest;
        var bestD = double.infinity;
        for (final candidate in samples) {
          final dr = r - nearestIndex(lats, candidate.point.latitude);
          final dc = c - nearestIndex(lngs, candidate.point.longitude);
          final d = dr * dr + dc * dc;
          if (d < bestD) { bestD = d.toDouble(); nearest = candidate; }
        }
        if (nearest != null) {
          complete.add(LayerSamplePoint(
            point: LatLng(lats[r], lngs[c]),
            value: nearest.value,
            directionDegrees: nearest.directionDegrees,
            u: nearest.u,
            v: nearest.v,
            source: nearest.source,
            updatedAt: nearest.updatedAt,
            isForecast: nearest.isForecast,
          ));
        }
      }
    }
    if (complete.length != nLat * nLng) return null;

    // The renderer expects row-major latitude/longitude order. lats ascend
    // from south to north and lngs ascend west to east.
    final ordered = <LayerSamplePoint>[];
    for (var r = 0; r < nLat; r++) {
      for (var c = 0; c < nLng; c++) {
        ordered.add(complete[r * nLng + c]);
      }
    }
    var minLat = lats.first;
    var maxLat = lats.last;
    var minLng = lngs.first;
    var maxLng = lngs.last;
    return _GridData(
      n: nLng,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      samples: ordered,
    );
  }

  double valueAtNormalized(double x, double y) {
    final gx = (x * (n - 1)).clamp(0.0, (n - 1).toDouble());
    final gy = (y * (n - 1)).clamp(0.0, (n - 1).toDouble());
    final x0 = gx.floor();
    final y0 = gy.floor();
    final x1 = math.min(x0 + 1, n - 1);
    final y1 = math.min(y0 + 1, n - 1);
    final tx = gx - x0;
    final ty = gy - y0;
    final a = samples[y0 * n + x0].value;
    final b = samples[y0 * n + x1].value;
    final c = samples[y1 * n + x0].value;
    final d = samples[y1 * n + x1].value;
    final top = a + (b - a) * tx;
    final bottom = c + (d - c) * tx;
    return top + (bottom - top) * ty;
  }

  ({double u, double v, double speed}) vectorAt(double lat, double lng) {
    final x = ((lng - minLng) / (maxLng - minLng)).clamp(0.0, 1.0).toDouble();
    final y = ((maxLat - lat) / (maxLat - minLat)).clamp(0.0, 1.0).toDouble();
    final gx = x * (n - 1);
    final gy = y * (n - 1);
    final x0 = gx.floor();
    final y0 = gy.floor();
    final x1 = math.min(x0 + 1, n - 1);
    final y1 = math.min(y0 + 1, n - 1);
    final tx = gx - x0;
    final ty = gy - y0;

    double component(double? Function(LayerSamplePoint) pick) {
      final a = pick(samples[y0 * n + x0]) ?? 0.0;
      final b = pick(samples[y0 * n + x1]) ?? 0.0;
      final c = pick(samples[y1 * n + x0]) ?? 0.0;
      final d = pick(samples[y1 * n + x1]) ?? 0.0;
      final top = a + (b - a) * tx;
      final bottom = c + (d - c) * tx;
      return top + (bottom - top) * ty;
    }

    final u = component((s) => s.u);
    final v = component((s) => s.v);
    return (u: u, v: v, speed: math.sqrt(u * u + v * v));
  }
}

Color _colorFor(WeatherLayerType layer, double value, {double? minValue, double? maxValue}) {
  final t = (minValue != null && maxValue != null && (maxValue - minValue).abs() > 0.000001)
      ? ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0).toDouble()
      : _normalize(layer, value).clamp(0.0, 1.0).toDouble();
  final p = _palette(layer);
  final scaled = t * (p.length - 1);
  final i = scaled.floor().clamp(0, p.length - 2).toInt();
  final c = Color.lerp(p[i], p[i + 1], scaled - i)!;
  final alpha = layer == WeatherLayerType.rain && value < 0.05
      ? 0
      : layer == WeatherLayerType.cloudCover
          ? (28 + t * 145).round().clamp(28, 173).toInt()
          : (65 + t * 150).round().clamp(55, 215).toInt();
  return c.withAlpha(alpha);
}

List<Color> _palette(WeatherLayerType layer) {
  switch (layer) {
    case WeatherLayerType.rain:
      return const [Color(0xFF17358F), Color(0xFF1B72D1), Color(0xFF21B8E6), Color(0xFF39CF72), Color(0xFFF2D83D), Color(0xFFFF7B21), Color(0xFFD91E32)];
    case WeatherLayerType.wind:
    case WeatherLayerType.windGust:
      return const [Color(0xFF3153B5), Color(0xFF2AAAD8), Color(0xFF39C96D), Color(0xFFE5D33A), Color(0xFFFF8A25), Color(0xFFE52D31)];
    case WeatherLayerType.temperature:
      return const [Color(0xFF3B4FC0), Color(0xFF2DB8E0), Color(0xFF4ACB6C), Color(0xFFFFD43B), Color(0xFFFF7A27), Color(0xFFE42D35)];
    case WeatherLayerType.so2:
    case WeatherLayerType.no2:
    case WeatherLayerType.pm25:
    case WeatherLayerType.pm10:
    case WeatherLayerType.co:
    case WeatherLayerType.ozone:
    case WeatherLayerType.airQuality:
      return const [Color(0xFF245CC5), Color(0xFF2BB8D0), Color(0xFF49C75D), Color(0xFFE4D23A), Color(0xFFFF8525), Color(0xFFE62E2E), Color(0xFF80152E)];
    case WeatherLayerType.cloudCover:
      return const [Color(0x00000000), Color(0xFFDDE3E8), Color(0xFFB8C1C9), Color(0xFF8C969F), Color(0xFF626D77)];
    case WeatherLayerType.humidity:
      return const [Color(0xFF254BA4), Color(0xFF35A9D2), Color(0xFF55C89B), Color(0xFFE5D047), Color(0xFFE9783A)];
    case WeatherLayerType.pressure:
      return const [Color(0xFF2D5CC4), Color(0xFF50B6D5), Color(0xFFE4D23E), Color(0xFFF08336), Color(0xFF8D2850)];
    default:
      return const [Color(0xFF3157C8), Color(0xFF35B8E8), Color(0xFF48C86B), Color(0xFFF0D13B), Color(0xFFE84A32)];
  }
}

double _pollutantMax(WeatherLayerType layer) {
  switch (layer) {
    case WeatherLayerType.so2: return 275;
    case WeatherLayerType.no2: return 150;
    case WeatherLayerType.pm25: return 140;
    case WeatherLayerType.pm10: return 270;
    case WeatherLayerType.co: return 10000;
    case WeatherLayerType.ozone: return 180;
    case WeatherLayerType.airQuality: return 100;
    default: return 100;
  }
}

double _normalize(WeatherLayerType layer, double value) {
  switch (layer) {
    case WeatherLayerType.temperature: return (value - 10) / 40;
    case WeatherLayerType.wind: return value / 60;
    case WeatherLayerType.windGust: return value / 90;
    case WeatherLayerType.rain: return value <= 5 ? value / 5 * .45 : .45 + (value - 5) / 45 * .55;
    case WeatherLayerType.humidity:
    case WeatherLayerType.cloudCover: return value / 100;
    case WeatherLayerType.uvIndex: return value / 12;
    case WeatherLayerType.pressure: return (value - 970) / 80;
    case WeatherLayerType.pm25: return value / 140;
    case WeatherLayerType.pm10: return value / 270;
    case WeatherLayerType.so2: return value / 275;
    case WeatherLayerType.no2: return value / 150;
    case WeatherLayerType.co: return value / 10000;
    case WeatherLayerType.ozone: return value / 180;
    case WeatherLayerType.airQuality: return value / 100;
    case WeatherLayerType.dewPoint: return (value + 10) / 50;
    case WeatherLayerType.visibility: return value / 30000;
    default: return .5;
  }
}

/// One lightweight canvas handles all animated particles. It never receives
/// pointer events, so map dragging stays with flutter_map.
class WeatherParticleOverlay extends StatefulWidget {
  final MapController mapController;
  final List<LayerSamplePoint> samples;
  final WeatherLayerType layer;

  const WeatherParticleOverlay({
    super.key,
    required this.mapController,
    required this.samples,
    required this.layer,
  });

  @override
  State<WeatherParticleOverlay> createState() => _WeatherParticleOverlayState();
}

class _WeatherParticleOverlayState extends State<WeatherParticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<_FlowParticle> _windParticles = [];
  final List<_RainParticle> _rainParticles = [];
  _GridData? _grid;
  _Bounds? _bounds;
  int _seed = 1;
  int _frame = 0;

  bool get _isWind => widget.layer == WeatherLayerType.wind || widget.layer == WeatherLayerType.windGust;
  bool get _isRain => widget.layer == WeatherLayerType.rain;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..addListener(_step)
      ..repeat();
    _refreshModel();
  }

  @override
  void didUpdateWidget(covariant WeatherParticleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer != widget.layer || oldWidget.samples.length != widget.samples.length) {
      _refreshModel();
    }
  }

  void _refreshModel() {
    _grid = _GridData.from(widget.samples);
    _bounds = _grid == null
        ? null
        : _Bounds(_grid!.minLat, _grid!.maxLat, _grid!.minLng, _grid!.maxLng);
    _seed++;
    _windParticles
      ..clear()
      ..addAll(List.generate(42, (i) => _FlowParticle(i, _seed)));
    if (_bounds != null) {
      for (final p in _windParticles) {
        p.respawn(_bounds!);
      }
    }
    _rainParticles
      ..clear()
      ..addAll(List.generate(28, (i) => _RainParticle(i, _seed)));
  }

  void _step() {
    if (!mounted || _grid == null) return;
    _frame++;
    // 20-24-ish fps is intentionally used instead of a 60fps Flutter rebuild.
    if (_frame % 3 != 0) return;
    const dt = 3.0 / 60.0;

    if (_isWind) {
      final bounds = _bounds!;
      final grid = _grid!;
      for (final p in _windParticles) {
        final vector = grid.vectorAt(p.lat, p.lon);
        final latDelta = vector.v * dt / 111.32;
        final cosLat = math.cos(p.lat * math.pi / 180).abs().clamp(.2, 1.0).toDouble();
        final lonDelta = vector.u * dt / (111.32 * cosLat);
        p.lat += latDelta;
        p.lon += lonDelta;
        if (p.lat < bounds.minLat || p.lat > bounds.maxLat || p.lon < bounds.minLng || p.lon > bounds.maxLng) {
          p.respawn(bounds);
        }
      }
    } else if (_isRain) {
      for (final p in _rainParticles) {
        p.y += dt * (.60 + p.length * .85);
        p.x += dt * p.sway * .08;
        if (p.y > 1.04) {
          p.y = -.04;
          p.x = (p.x + .41) % 1.0;
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if ((!_isWind && !_isRain) || _grid == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _WeatherParticlePainter(
              mapController: widget.mapController,
              grid: _grid!,
              layer: widget.layer,
              windParticles: List<_FlowParticle>.unmodifiable(_windParticles),
              rainParticles: List<_RainParticle>.unmodifiable(_rainParticles),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class _WeatherParticlePainter extends CustomPainter {
  final MapController mapController;
  final _GridData grid;
  final WeatherLayerType layer;
  final List<_FlowParticle> windParticles;
  final List<_RainParticle> rainParticles;

  const _WeatherParticlePainter({
    required this.mapController,
    required this.grid,
    required this.layer,
    required this.windParticles,
    required this.rainParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (layer == WeatherLayerType.wind || layer == WeatherLayerType.windGust) {
      for (final p in windParticles) {
        final point = mapController.camera.latLngToScreenOffset(LatLng(p.lat, p.lon));
        if (!point.dx.isFinite || !point.dy.isFinite) continue;
        final v = grid.vectorAt(p.lat, p.lon);
        if (v.speed < .25) continue;
        final angle = math.atan2(-v.v, v.u);
        final length = (4.0 + v.speed * .32).clamp(5.0, 13.0).toDouble();
        final dx = math.cos(angle) * length;
        final dy = math.sin(angle) * length;
        final paint = Paint()
          ..color = Color.lerp(const Color(0xFFB7FFD9), const Color(0xFF18C987), (v.speed / 45).clamp(0.0, 1.0).toDouble())!
              .withOpacity((.48 + (v.speed / 55).clamp(0.0, .28).toDouble()) * p.opacity)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(point - Offset(dx, dy) * .5, point + Offset(dx, dy) * .5, paint);
      }
    } else if (layer == WeatherLayerType.rain) {
      for (final p in rainParticles) {
        final lat = grid.maxLat - (grid.maxLat - grid.minLat) * p.y;
        final lng = grid.minLng + (grid.maxLng - grid.minLng) * p.x;
        final rain = grid.valueAtNormalized(p.x.clamp(0.0, 1.0).toDouble(), p.y.clamp(0.0, 1.0).toDouble());
        if (rain < .08) continue;
        final point = mapController.camera.latLngToScreenOffset(LatLng(lat, lng));
        if (!point.dx.isFinite || !point.dy.isFinite) continue;
        final intensity = (rain / 12).clamp(0.0, 1.0).toDouble();
        final length = 5.0 + intensity * 8.0;
        final paint = Paint()
          ..color = Colors.white.withOpacity(.26 + intensity * .48)
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(point, point + Offset(-length * .16, length), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherParticlePainter oldDelegate) => true;
}

class _FlowParticle {
  double lat = 0;
  double lon = 0;
  final double opacity;
  final int index;

  _FlowParticle(this.index, int seed)
      : opacity = .45 + ((index * 17 + seed * 7) % 45) / 100;

  void respawn(_Bounds b) {
    final a = ((index * 73 + _seedHash(index)) % 997) / 996;
    final c = ((index * 41 + _seedHash(index + 9)) % 991) / 990;
    lat = b.minLat + (b.maxLat - b.minLat) * a;
    lon = b.minLng + (b.maxLng - b.minLng) * c;
  }
}

int _seedHash(int n) => (n * 1103515245 + 12345) & 0x7fffffff;

class _RainParticle {
  double x;
  double y;
  final double length;
  final double sway;

  _RainParticle(int i, int seed)
      : x = ((i * 47 + seed * 13) % 997) / 996,
        y = ((i * 61 + seed * 17) % 991) / 990,
        length = .7 + ((i * 11) % 50) / 50,
        sway = (((i * 23) % 20) - 10) / 10;
}

class _Bounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  const _Bounds(this.minLat, this.maxLat, this.minLng, this.maxLng);
}
