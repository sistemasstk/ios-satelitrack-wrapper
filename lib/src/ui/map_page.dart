import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  Timer? _followTimer;

  bool _loading = false;
  bool _followSelectedVehicle = false;
  String? _selectedPlate;
  String? _error;
  List<VehiclePosition> _items = const <VehiclePosition>[];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _followTimer?.cancel();
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
      setState(() {
        _items = data;
      });

      if (data.isEmpty) {
        return;
      }

      if (_selectedPlate != null) {
        final VehiclePosition? found = _findSelectedVehicle();
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

  void _toggleFollow(bool enabled) {
    setState(() => _followSelectedVehicle = enabled);
    _followTimer?.cancel();

    if (!enabled) {
      return;
    }

    _followTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
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
    final String? plate = _selectedPlate;
    if (plate == null || plate.isEmpty) {
      return null;
    }
    for (final VehiclePosition item in _items) {
      if (item.plate.toUpperCase() == plate.toUpperCase()) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> plates = _items.map((VehiclePosition p) => p.plate).toSet().toList()..sort();
    final String? selected = (plates.contains(_selectedPlate)) ? _selectedPlate : null;
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
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selected,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Buscar placa',
                      isDense: true,
                    ),
                    items: plates
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
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
  });

  final String plate;
  final String ignition;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color markerColor = ignition == 'On' ? const Color(0xff2e7d32) : const Color(0xffc62828);
    return Column(
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
    );
  }
}
