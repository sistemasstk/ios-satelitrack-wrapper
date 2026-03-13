import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/domain_models.dart';
import '../theme/app_palette.dart';

class TravelPlaybackPage extends StatefulWidget {
  const TravelPlaybackPage({
    super.key,
    required this.plate,
    required this.points,
    this.initialIndex = 0,
    this.autoplay = false,
    this.title = 'Simulacion de recorrido',
  });

  final String plate;
  final List<TravelHistoryItem> points;
  final int initialIndex;
  final bool autoplay;
  final String title;

  @override
  State<TravelPlaybackPage> createState() => _TravelPlaybackPageState();
}

class _TravelPlaybackPageState extends State<TravelPlaybackPage> {
  final MapController _mapController = MapController();

  Timer? _playbackTimer;
  int _currentIndex = 0;
  bool _playing = false;
  double _speed = 1;

  List<TravelHistoryItem> get _validPoints =>
      widget.points.where((TravelHistoryItem item) => item.hasCoordinate).toList(growable: false);

  TravelHistoryItem get _currentPoint => _validPoints[_currentIndex];

  @override
  void initState() {
    super.initState();
    final int pointCount = _validPoints.length;
    _currentIndex = pointCount == 0
        ? 0
        : (widget.initialIndex.clamp(0, pointCount - 1) as int);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _validPoints.isEmpty) {
        return;
      }
      _fitOrMoveToCurrent();
      if (widget.autoplay && _validPoints.length > 1) {
        _togglePlayback();
      }
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _fitOrMoveToCurrent() {
    if (_validPoints.isEmpty) {
      return;
    }

    final TravelHistoryItem current = _currentPoint;
    if (_validPoints.length < 2) {
      _safeMove(LatLng(current.latitude, current.longitude), 15);
      return;
    }

    final List<LatLng> latLngs = _validPoints
        .map((TravelHistoryItem item) => LatLng(item.latitude, item.longitude))
        .toList(growable: false);
    final LatLngBounds bounds = LatLngBounds.fromPoints(latLngs);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(42),
        ),
      );
    } catch (_) {
      _safeMove(LatLng(current.latitude, current.longitude), 13);
    }
  }

  void _safeMove(LatLng point, double zoom) {
    try {
      _mapController.move(point, zoom);
    } catch (_) {
      // Ignore transient move errors before map is attached.
    }
  }

  void _togglePlayback() {
    if (_validPoints.length < 2) {
      return;
    }

    if (_playing) {
      _playbackTimer?.cancel();
      setState(() => _playing = false);
      return;
    }

    if (_currentIndex >= _validPoints.length - 1) {
      _currentIndex = 0;
    }

    setState(() => _playing = true);
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(_intervalForSpeed(), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentIndex >= _validPoints.length - 1) {
        timer.cancel();
        setState(() => _playing = false);
        return;
      }

      setState(() => _currentIndex += 1);
      final TravelHistoryItem item = _currentPoint;
      _safeMove(LatLng(item.latitude, item.longitude), 15);
    });
  }

  Duration _intervalForSpeed() {
    if (_speed >= 4) {
      return const Duration(milliseconds: 240);
    }
    if (_speed >= 2) {
      return const Duration(milliseconds: 420);
    }
    return const Duration(milliseconds: 800);
  }

  void _setSpeed(double value) {
    setState(() => _speed = value);
    if (_playing) {
      _togglePlayback();
      _togglePlayback();
    }
  }

  void _setCurrentIndex(int value) {
    if (_validPoints.isEmpty) {
      return;
    }
    setState(() => _currentIndex = value.clamp(0, _validPoints.length - 1) as int);
    final TravelHistoryItem item = _currentPoint;
    _safeMove(LatLng(item.latitude, item.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    if (_validPoints.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No hay puntos con coordenadas para reproducir este recorrido.'),
          ),
        ),
      );
    }

    final TravelHistoryItem point = _currentPoint;
    final List<LatLng> route = _validPoints
        .map((TravelHistoryItem item) => LatLng(item.latitude, item.longitude))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.plate,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatBackendDateTime(point.gpsDate),
                    style: const TextStyle(color: AppPalette.midGreen),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetricPill(
                        label: 'Punto',
                        value: '${_currentIndex + 1} / ${_validPoints.length}',
                      ),
                      _MetricPill(
                        label: 'Velocidad',
                        value: '${point.speed} km/h',
                      ),
                      _MetricPill(
                        label: 'Ignicion',
                        value: point.ignition,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 380,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(point.latitude, point.longitude),
                  initialZoom: 14,
                  onTap: (_, __) => FocusScope.of(context).unfocus(),
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'co.com.satelitrack.native',
                  ),
                  PolylineLayer(
                    polylines: <Polyline>[
                      Polyline(
                        points: route,
                        color: AppPalette.markerSelected,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: route.first,
                        width: 34,
                        height: 34,
                        child: const Icon(Icons.flag_circle, color: AppPalette.midGreen),
                      ),
                      Marker(
                        point: route.last,
                        width: 34,
                        height: 34,
                        child: const Icon(Icons.outlined_flag, color: Colors.redAccent),
                      ),
                      Marker(
                        point: LatLng(point.latitude, point.longitude),
                        width: 160,
                        height: 72,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppPalette.borderSoft),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x18000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                formatBackendDateTime(point.gpsDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Icon(Icons.place, color: AppPalette.markerSelected, size: 28),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _togglePlayback,
                          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                          label: Text(_playing ? 'Pausar' : 'Simular'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _currentIndex == 0
                            ? null
                            : () => _setCurrentIndex(0),
                        icon: const Icon(Icons.replay),
                        label: const Text('Inicio'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_validPoints.length > 1) ...<Widget>[
                    Slider(
                      value: _currentIndex.toDouble(),
                      min: 0,
                      max: (_validPoints.length - 1).toDouble(),
                      divisions: _validPoints.length - 1,
                      label: '${_currentIndex + 1}',
                      onChanged: (double value) => _setCurrentIndex(value.round()),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: <Widget>[
                      const Text('Velocidad de simulacion'),
                      const Spacer(),
                      SegmentedButton<double>(
                        segments: const <ButtonSegment<double>>[
                          ButtonSegment<double>(value: 1.0, label: Text('1x')),
                          ButtonSegment<double>(value: 2.0, label: Text('2x')),
                          ButtonSegment<double>(value: 4.0, label: Text('4x')),
                        ],
                        selected: <double>{_speed},
                        onSelectionChanged: (Set<double> values) {
                          if (values.isEmpty) {
                            return;
                          }
                          _setSpeed(values.first);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Posicion actual en la reproduccion',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(point.position),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetricPill(label: 'Latitud', value: point.latitude.toStringAsFixed(6)),
                      _MetricPill(label: 'Longitud', value: point.longitude.toStringAsFixed(6)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.softGreenSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderSoft),
      ),
      child: Text('$label: $value'),
    );
  }
}
