import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/config/weather_map_config.dart';
import '../../models/map_layer_type.dart';
import '../../models/weather_point_reading.dart';
import 'package:latlong2/latlong.dart';

class MercatorWeatherMap extends StatefulWidget {
  final WeatherLayerType layer;
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final ValueNotifier<({double latitude, double longitude, double zoom})?>? viewCommand;
  final ValueChanged<String>? onStatus;
  final ValueChanged<({double latitude, double longitude, double zoom})>? onCameraChanged;
  final LatLng? selectedPoint;
  final String? selectedLabel;
  final ValueChanged<WeatherPointReading?>? onPointReading;
  final ValueChanged<LatLng>? onMapPointSelected;

  const MercatorWeatherMap({
    super.key,
    required this.layer,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialZoom,
    this.viewCommand,
    this.onStatus,
    this.onCameraChanged,
    this.selectedPoint,
    this.selectedLabel,
    this.onPointReading,
    this.onMapPointSelected,
  });

  @override
  State<MercatorWeatherMap> createState() => MercatorWeatherMapState();
}

class MercatorWeatherMapState extends State<MercatorWeatherMap> {
  late final WebViewController _controller;
  bool _ready = false;
  String _status = 'Menyiapkan peta…';
  ({double latitude, double longitude, double zoom})? _pendingView;
  String? _lastDataset;
  LatLng? _lastSelectedPoint;
  VoidCallback? _viewCommandListener;
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _viewCommandListener = () {
      final command = widget.viewCommand?.value;
      if (command != null) {
        setView(
          latitude: command.latitude,
          longitude: command.longitude,
          zoom: command.zoom,
        );
      }
    };
    widget.viewCommand?.addListener(_viewCommandListener!);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1720))
      ..addJavaScriptChannel('FloodGuard', onMessageReceived: _onMessage)
      ..loadHtmlString(_html(), baseUrl: 'https://mercator.blue/');

    // Re-check the Mercator global field periodically. Mercator publishes
    // weather forecast cycles every ~6 hours and CAMS air-quality fields
    // twice daily; this timer is deliberately longer than a normal UI
    // refresh so we do not hammer the tile service. The SDK itself resolves
    // the newest published cycle whenever a layer is created.
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || !_ready || _lastDataset == null) return;
      _controller.runJavaScript(
        'window.FloodGuardWeather && window.FloodGuardWeather.refresh();',
      );
    });
  }

  String _dataset(WeatherLayerType layer) {
    switch (layer) {
      case WeatherLayerType.wind: return 'wind10m';
      case WeatherLayerType.windGust: return 'gust';
      case WeatherLayerType.temperature: return 'temp2m';
      case WeatherLayerType.humidity: return 'humidity2m';
      case WeatherLayerType.pressure: return 'mslp';
      case WeatherLayerType.cloudCover: return 'cloudcover';
      case WeatherLayerType.visibility: return 'visibility';
      case WeatherLayerType.pm25: return 'pm25';
      case WeatherLayerType.pm10: return 'pm10';
      case WeatherLayerType.so2: return 'so2';
      case WeatherLayerType.no2: return 'no2';
      case WeatherLayerType.co: return 'co';
      case WeatherLayerType.ozone: return 'ozone';
      case WeatherLayerType.rain: return 'precip3h';
      case WeatherLayerType.dewPoint: return 'temp2m';
      case WeatherLayerType.uvIndex: return 'temp2m';
      case WeatherLayerType.airQuality: return 'pm25';
      case WeatherLayerType.radar: return 'reflectivity';
      case WeatherLayerType.satellite: return 'temp2m';
      case WeatherLayerType.waves: return 'temp2m';
      case WeatherLayerType.seaTemperature: return 'temp2m';
    }
  }

  bool _isWind(WeatherLayerType layer) =>
      layer == WeatherLayerType.wind;

  String _title(WeatherLayerType layer) =>
      weatherLayerConfigs[layer]?.title ?? 'Cuaca';

  void _setStatus(String value) {
    if (!mounted) return;
    void apply() {
      if (!mounted) return;
      if (_status != value) setState(() => _status = value);
      widget.onStatus?.call(value);
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final raw = message.message;

    if (raw == 'ready') {
      _ready = true;
      _lastDataset = null;
      _setStatus('Peta siap · memuat ${_title(widget.layer)}…');
      final pendingView = _pendingView;
      _pendingView = null;
      if (pendingView != null) {
        setView(
          latitude: pendingView.latitude,
          longitude: pendingView.longitude,
          zoom: pendingView.zoom,
        );
      }
      if (widget.selectedPoint != null) setPoint(widget.selectedPoint!);
      setLayer(widget.layer);
      return;
    }

    if (raw == 'map_ready') {
      _setStatus('Peta siap · memuat ${_title(widget.layer)}…');
      return;
    }

    if (raw.startsWith('status:')) {
      _setStatus(raw.substring(7));
      return;
    }

    if (raw.startsWith('error:')) {
      _lastDataset = null;
      _setStatus(raw.substring(6));
      return;
    }

    if (raw.startsWith('point:')) {
      final p = raw.substring(6).split(',');
      if (p.length == 2) {
        final lat = double.tryParse(p[0]);
        final lon = double.tryParse(p[1]);
        if (lat != null && lon != null) {
          widget.onMapPointSelected?.call(LatLng(lat, lon));
        }
      }
      return;
    }

    if (raw.startsWith('camera:')) {
      final p = raw.substring(7).split(',');
      if (p.length == 3) {
        final lat = double.tryParse(p[0]);
        final lon = double.tryParse(p[1]);
        final zoom = double.tryParse(p[2]);
        if (lat != null && lon != null && zoom != null) {
          widget.onCameraChanged?.call(
            (latitude: lat, longitude: lon, zoom: zoom),
          );
        }
      }
    }
  }

  void setLayer(WeatherLayerType layer) {
    if (!_ready) return;
    final config = weatherLayerConfigs[layer];
    if (config != null && !config.supported) {
      _setStatus('${_title(layer)} · belum tersedia');
      return;
    }
    final dataset = _dataset(layer);
    final wind = _isWind(layer);
    final key = '$dataset:$wind';
    if (_lastDataset == key) return;
    _lastDataset = key;
    _setStatus('Memuat ${_title(layer)} · global…');
    _controller.runJavaScript(
      'window.FloodGuardWeather && '
      'window.FloodGuardWeather.setLayer(${jsonEncode(dataset)}, $wind);',
    );
  }

  void setPoint(LatLng point) {
    _lastSelectedPoint = point;
    if (!_ready) return;
    _controller.runJavaScript(
      'window.FloodGuardWeather && window.FloodGuardWeather.setPoint(${point.latitude},${point.longitude});',
    );
  }

  void setView({
    required double latitude,
    required double longitude,
    required double zoom,
  }) {
    if (!_ready) {
      _pendingView = (latitude: latitude, longitude: longitude, zoom: zoom);
      return;
    }
    _controller.runJavaScript(
      'window.FloodGuardWeather && '
      'window.FloodGuardWeather.setView($latitude,$longitude,$zoom);',
    );
  }

  @override
  void didUpdateWidget(covariant MercatorWeatherMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewCommand != widget.viewCommand) {
      oldWidget.viewCommand?.removeListener(_viewCommandListener!);
      widget.viewCommand?.addListener(_viewCommandListener!);
    }
    if (oldWidget.layer != widget.layer) {
      setLayer(widget.layer);
    }
    if (oldWidget.selectedPoint != widget.selectedPoint && widget.selectedPoint != null) {
      _lastSelectedPoint = widget.selectedPoint;
      setPoint(widget.selectedPoint!);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.viewCommand?.removeListener(_viewCommandListener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!WeatherMapConfig.isConfigured) return const _MissingKeyView();
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        Positioned(
          left: 14,
          bottom: 14,
          child: IgnorePointer(child: _EngineBadge(status: _status)),
        ),
      ],
    );
  }

  String _html() {
    final key = jsonEncode(WeatherMapConfig.apiKey);
    final catalog = jsonEncode(WeatherMapConfig.catalogUrl);
    final style = jsonEncode(WeatherMapConfig.mapStyle);

    return '''<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<link rel="stylesheet" href="https://unpkg.com/maplibre-gl@5.7.0/dist/maplibre-gl.css">
<style>
html,body,#map{width:100%;height:100%;margin:0;padding:0;overflow:hidden;background:#0d1720}
.maplibregl-ctrl-attrib{font-size:9px!important;background:rgba(255,255,255,.72)!important}
.search-marker{width:34px;height:34px;border-radius:50% 50% 50% 0;background:#E53935;border:3px solid #fff;box-shadow:0 4px 12px rgba(0,0,0,.35);transform:rotate(-45deg);display:flex;align-items:center;justify-content:center}
.search-marker:after{content:'';width:9px;height:9px;border-radius:50%;background:#fff}
</style>
</head>
<body>
<div id="map"></div>
<script type="module">
import maplibregl from 'https://esm.sh/maplibre-gl@5.7.0?target=es2022';
import { MercatorLayer } from 'https://esm.sh/@mercator-blue/sdk@latest/mapbox?deps=maplibre-gl@5.7.0';

const KEY = $key;
const CATALOG = $catalog;
const STYLE = $style;
let map = null;
let raster = null;
let flow = null;
let requestId = 0;
let loading = false;
let pending = null;
let activeKey = '';
let selectedMarker = null;

function post(value) {
  try { FloodGuard.postMessage(value); } catch (_) {}
}

function removeLayer(layer) {
  try { if (layer) layer.remove(); } catch (_) {}
}

function repaint() {
  try { map && map.resize(); } catch (_) {}
  try { map && map.triggerRepaint(); } catch (_) {}
}

async function buildRaster(dataset, id) {
  const layer = await MercatorLayer.create({
    dataset: dataset,
    apiKey: KEY,
    catalogUrl: CATALOG,
    viz: 'raster',
    opacity: 0.62,
    smooth: true,
    colormap: 'turbo'
  });
  if (id !== requestId) {
    removeLayer(layer);
    return null;
  }
  layer.addTo(map);
  repaint();
  return layer;
}

async function buildWindFlow(id) {
  const layer = await MercatorLayer.create({
    dataset: 'wind10m',
    apiKey: KEY,
    catalogUrl: CATALOG,
    viz: 'streamlines',
    particleCount: 6000,
    pointSize: 2.4,
    speedScale: 6e-5,
    fade: 0.985,
    colorBySpeed: true,
    opacity: 0.90,
    colormap: 'turbo'
  });
  if (id !== requestId) {
    removeLayer(layer);
    return null;
  }
  layer.addTo(map);
  repaint();
  return layer;
}

async function processLayer(dataset, isWind, id) {
  const key = dataset + ':' + isWind;
  if (key === activeKey) {
    post('status:Global field aktif');
    return;
  }

  post('status:Memuat ' + dataset + ' · global…');
  let nextRaster = null;
  let nextFlow = null;

  try {
    nextRaster = await buildRaster(dataset, id);
    if (!nextRaster || id !== requestId) return;

    if (isWind) {
      nextFlow = await buildWindFlow(id);
      if (!nextFlow || id !== requestId) {
        removeLayer(nextRaster);
        return;
      }
    }

    if (id !== requestId) {
      removeLayer(nextFlow);
      removeLayer(nextRaster);
      return;
    }

    removeLayer(flow);
    removeLayer(raster);
    flow = nextFlow;
    raster = nextRaster;
    activeKey = key;
    post('status:Global field aktif');
  } catch (error) {
    console.error('[FloodGuard Mercator] layer load failed', error);
    post('status:Memuat ' + dataset + ' · mencoba lagi…');
    removeLayer(nextFlow);
    removeLayer(nextRaster);
    if (id !== requestId) return;

    // Satu retry otomatis untuk kegagalan jaringan/SDK yang transient.
    // Jangan tampilkan pesan ERROR di UI pada kegagalan pertama karena
    // user bisa sedang melakukan search/pindah lokasi bersamaan.
    await new Promise((resolve) => setTimeout(resolve, 450));
    if (id !== requestId) return;
    try {
      const retryRaster = await buildRaster(dataset, id);
      if (!retryRaster || id !== requestId) return;
      let retryFlow = null;
      if (isWind) {
        retryFlow = await buildWindFlow(id);
        if (!retryFlow || id !== requestId) {
          removeLayer(retryRaster);
          return;
        }
      }
      if (id !== requestId) {
        removeLayer(retryFlow);
        removeLayer(retryRaster);
        return;
      }
      removeLayer(flow);
      removeLayer(raster);
      flow = retryFlow;
      raster = retryRaster;
      activeKey = key;
      post('status:Global field aktif');
    } catch (retryError) {
      console.error('[FloodGuard Mercator] retry failed', retryError);
      if (id === requestId) {
        post('error:' + dataset + ' gagal dimuat · cek koneksi/API key');
      }
    }
  }
}

async function setLayer(dataset, isWind, force) {
  if (!map) return;

  const id = ++requestId;
  if (force) activeKey = '';
  pending = { dataset: dataset, isWind: isWind, id: id };
  if (loading) return;
  loading = true;

  try {
    while (pending) {
      const request = pending;
      pending = null;
      await processLayer(request.dataset, request.isWind, request.id);
    }
  } finally {
    loading = false;
  }
}

function setView(lat, lon, zoom) {
  if (!map) return;
  map.jumpTo({ center: [lon, lat], zoom: zoom });
}

function setPoint(lat, lon) {
  if (!map) return;
  const element = document.createElement('div');
  element.className = 'search-marker';
  if (selectedMarker) {
    try { selectedMarker.remove(); } catch (_) {}
  }
  selectedMarker = new maplibregl.Marker({element, anchor: 'bottom'})
    .setLngLat([lon, lat])
    .addTo(map);
}

window.FloodGuardWeather = {
  setLayer: setLayer,
  setView: setView,
  setPoint: setPoint,
  refresh: function () {
    if (!map || !activeKey) return;
    const parts = activeKey.split(':');
    setLayer(parts[0], parts[1] === 'true', true);
  }
};

try {
  if (!KEY) {
    post('error:Mercator API key belum diatur');
  } else {
    map = new maplibregl.Map({
      container: 'map',
      style: STYLE,
      center: [118, -2.5],
      zoom: 4.6,
      renderWorldCopies: true,
      attributionControl: true
    });

    map.on('moveend', function () {
      const center = map.getCenter();
      post('camera:' + center.lat + ',' + center.lng + ',' + map.getZoom());
    });

    map.on('click', function (event) {
      post('point:' + event.lngLat.lat + ',' + event.lngLat.lng);
    });

    map.on('load', function () {
      repaint();
      post('map_ready');
      post('ready');
    });
  }
} catch (_) {
  post('error:MapLibre gagal dimuat');
}
</script>
</body>
</html>''';
  }
}

class _EngineBadge extends StatelessWidget {
  final String status;
  const _EngineBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE61B2A38),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MissingKeyView extends StatelessWidget {
  const _MissingKeyView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F5F7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 48, color: Color(0xFF1976D2)),
          SizedBox(height: 12),
          Text(
            'Weather Map belum dikonfigurasi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Tambahkan MERCATOR_API_KEY melalui --dart-define untuk mengaktifkan global weather field.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
