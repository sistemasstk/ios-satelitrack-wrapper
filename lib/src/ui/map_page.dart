import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';
import 'vehicle_detail_page.dart';

enum _MapLayerType {
  streets,
  satellite,
  hybrid,
}

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _plateFilterController = TextEditingController();

  Timer? _followTimer;
  Timer? _movementTimer;

  bool _loading = false;
  bool _followSelectedVehicle = false;
  String? _selectedPlate;
  String _plateFilter = '';
  String? _error;
  _MapLayerType _layerType = _MapLayerType.streets;
  List<VehiclePosition> _items = const <VehiclePosition>[];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _followTimer?.cancel();
    _movementTimer?.cancel();
    _plateFilterController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.controller.refreshDashboard(silent: true);
      if (!mounted) {
        return;
      }

      final List<VehiclePosition> data =
          widget.controller.positions.where((VehiclePosition p) => p.hasCoordinate).toList();

      if (_selectedPlate != null && !data.any((VehiclePosition v) => v.plate == _selectedPlate)) {
        _selectedPlate = null;
        _followSelectedVehicle = false;
      }

      _animateToNewPositions(data);

      if (data.isEmpty) {
        return;
      }

      if (_selectedPlate != null) {
        final VehiclePosition? found = _findByPlate(_selectedPlate, data);
        if (found != null) {
          _moveMap(LatLng(found.latitude, found.longitude), _currentZoomOr(8));
          return;
        }
      }

      final VehiclePosition first = data.first;
      _moveMap(LatLng(first.latitude, first.longitude), 6.5);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ex.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _animateToNewPositions(List<VehiclePosition> target) {
    _movementTimer?.cancel();

    if (_items.isEmpty || target.isEmpty) {
      setState(() => _items = target);
      return;
    }

    final Map<String, VehiclePosition> previousByPlate = <String, VehiclePosition>{
      for (final VehiclePosition item in _items) item.plate.toUpperCase(): item,
    };

    const int steps = 8;
    int step = 0;

    _movementTimer = Timer.periodic(const Duration(milliseconds: 120), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      step++;
      final double t = step / steps;

      if (t >= 1) {
        setState(() => _items = target);
        timer.cancel();
        return;
      }

      final List<VehiclePosition> interpolated = target.map((VehiclePosition current) {
        final VehiclePosition? previous = previousByPlate[current.plate.toUpperCase()];
        if (previous == null || !previous.hasCoordinate || !current.hasCoordinate) {
          return current;
        }

        final double latitude = previous.latitude + ((current.latitude - previous.latitude) * t);
        final double longitude = previous.longitude + ((current.longitude - previous.longitude) * t);

        return VehiclePosition(
          plate: current.plate,
          reportDate: current.reportDate,
          ignitionLabel: current.ignitionLabel,
          position: current.position,
          speed: current.speed,
          kmDay: current.kmDay,
          kmTotal: current.kmTotal,
          horometerLabel: current.horometerLabel,
          deviceId: current.deviceId,
          imageName: current.imageName,
          latitude: latitude,
          longitude: longitude,
        );
      }).toList();

      setState(() => _items = interpolated);
    });
  }

  void _toggleFollow(bool enabled) {
    setState(() => _followSelectedVehicle = enabled);
    _followTimer?.cancel();

    if (!enabled) {
      return;
    }

    _followTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted || !_followSelectedVehicle) {
        return;
      }
      await _refresh();
      final VehiclePosition? selected = _findSelectedVehicle();
      if (selected != null) {
        _moveMap(
          LatLng(selected.latitude, selected.longitude),
          _currentZoomOr(8) < 8 ? 8 : _currentZoomOr(8),
        );
      }
    });
  }

  VehiclePosition? _findSelectedVehicle() {
    return _findByPlate(_selectedPlate, _items);
  }

  VehiclePosition? _findByPlate(String? plate, List<VehiclePosition> source) {
    if (plate == null || plate.isEmpty) {
      return null;
    }
    for (final VehiclePosition item in source) {
      if (item.plate.toUpperCase() == plate.toUpperCase()) {
        return item;
      }
    }
    return null;
  }

  void _openVehicleDetail(VehiclePosition item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleDetailPage(
          controller: widget.controller,
          initialPosition: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> allPlates = _items.map((VehiclePosition p) => p.plate).toSet().toList()..sort();
    final String filter = _plateFilter.trim().toLowerCase();
    final List<String> filteredPlates = filter.isEmpty
        ? allPlates
        : allPlates.where((String plate) => plate.toLowerCase().contains(filter)).toList();

    final String? selected = filteredPlates.contains(_selectedPlate) ? _selectedPlate : null;
    final LatLng center = _initialCenter();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de flota'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          PopupMenuButton<_MapLayerType>(
            tooltip: 'Capas',
            initialValue: _layerType,
            onSelected: (_MapLayerType value) => setState(() => _layerType = value),
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<_MapLayerType>>[
              PopupMenuItem<_MapLayerType>(
                value: _MapLayerType.streets,
                child: Text('Calles'),
              ),
              PopupMenuItem<_MapLayerType>(
                value: _MapLayerType.satellite,
                child: Text('Satelite'),
              ),
              PopupMenuItem<_MapLayerType>(
                value: _MapLayerType.hybrid,
                child: Text('Hibrido'),
              ),
            ],
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _plateFilterController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Filtrar placas',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _plateFilter.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _plateFilterController.clear();
                              setState(() => _plateFilter = '');
                            },
                          ),
                  ),
                  onChanged: (String value) => setState(() => _plateFilter = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selected,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Buscar placa',
                          isDense: true,
                        ),
                        items: filteredPlates
                            .map(
                              (String plate) => DropdownMenuItem<String>(
                                value: plate,
                                child: Text(plate),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          setState(() {
                            _selectedPlate = value;
                            if (value == null && _followSelectedVehicle) {
                              _followSelectedVehicle = false;
                              _followTimer?.cancel();
                            }
                          });
                          final VehiclePosition? selectedItem = _findSelectedVehicle();
                          if (selectedItem != null) {
                            _moveMap(
                              LatLng(selectedItem.latitude, selectedItem.longitude),
                              _currentZoomOr(9) < 9 ? 9 : _currentZoomOr(9),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: <Widget>[
                        const Text('Seguir', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: _followSelectedVehicle,
                          onChanged: selected == null ? null : _toggleFollow,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if ((_error ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xfffff3cd),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 5.8,
                    minZoom: 3,
                    maxZoom: 18,
                  ),
                  children: <Widget>[
                    _buildBaseLayer(),
                    if (_layerType == _MapLayerType.hybrid)
                      TileLayer(
                        urlTemplate:
                            'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'co.com.satelitrack.native',
                      ),
                    MarkerLayer(
                      markers: _items
                          .map(
                            (VehiclePosition item) => Marker(
                              point: LatLng(item.latitude, item.longitude),
                              width: 120,
                              height: 46,
                              alignment: Alignment.topCenter,
                              child: _VehicleMarker(
                                plate: item.plate,
                                ignition: item.ignitionLabel,
                                selected: item.plate == selected,
                                onTap: () => _openVehicleDetail(item),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                if (_loading)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TileLayer _buildBaseLayer() {
    switch (_layerType) {
      case _MapLayerType.satellite:
      case _MapLayerType.hybrid:
        return TileLayer(
          urlTemplate:
              'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'co.com.satelitrack.native',
        );
      case _MapLayerType.streets:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'co.com.satelitrack.native',
        );
    }
  }

  LatLng _initialCenter() {
    if (_items.isNotEmpty) {
      return LatLng(_items.first.latitude, _items.first.longitude);
    }
    return const LatLng(4.711, -74.0721);
  }

  void _moveMap(LatLng point, double zoom) {
    try {
      _mapController.move(point, zoom);
    } catch (_) {
      // Ignore transient move errors before map is fully attached.
    }
  }

  double _currentZoomOr(double fallback) {
    try {
      return _mapController.camera.zoom;
    } catch (_) {
      return fallback;
    }
  }
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({
    required this.plate,
    required this.ignition,
    required this.selected,
    required this.onTap,
  });

  final String plate;
  final String ignition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color markerColor = ignition == 'On' ? const Color(0xff2e7d32) : const Color(0xffc62828);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? const Color(0xff0d47a1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffcfd8e3)),
            ),
            child: Text(
              plate,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xff1e293b),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Icon(Icons.place, color: markerColor, size: 22),
        ],
      ),
    );
  }
}
