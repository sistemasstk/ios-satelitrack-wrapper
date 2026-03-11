import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';

class GeofencesPage extends StatefulWidget {
  const GeofencesPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<GeofencesPage> createState() => _GeofencesPageState();
}

class _GeofencesPageState extends State<GeofencesPage> {
  final MapController _zonesMapController = MapController();
  final TextEditingController _newZoneNameController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<GeofenceZone> _zones = const <GeofenceZone>[];
  List<VehicleRef> _vehicles = const <VehicleRef>[];
  int? _selectedZoneId;
  int? _selectedVehicleId;
  bool _useSchedule = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  final List<GeoPoint> _draftPolygon = <GeoPoint>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _newZoneNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.controller.loadGeofences(),
        widget.controller.loadVehicles(),
      ]);
      if (!mounted) {
        return;
      }

      final List<GeofenceZone> zones = result[0] as List<GeofenceZone>;
      final List<VehicleRef> vehicles = result[1] as List<VehicleRef>;

      setState(() {
        _zones = zones;
        _vehicles = vehicles;
        _selectedZoneId = _normalizeSelection(
          currentValue: _selectedZoneId,
          options: zones.map((GeofenceZone z) => z.id).toList(),
        );
        _selectedVehicleId = _normalizeSelection(
          currentValue: _selectedVehicleId,
          options: vehicles.map((VehicleRef v) => v.idMovil).toList(),
        );
      });

      _focusSelectedZone();
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() => _error = ex.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int? _normalizeSelection({
    required int? currentValue,
    required List<int> options,
  }) {
    if (currentValue != null && options.contains(currentValue)) {
      return currentValue;
    }
    if (options.isNotEmpty) {
      return options.first;
    }
    return null;
  }

  GeofenceZone? _selectedZone() {
    final int? id = _selectedZoneId;
    if (id == null) {
      return null;
    }
    for (final GeofenceZone zone in _zones) {
      if (zone.id == id) {
        return zone;
      }
    }
    return null;
  }

  void _focusSelectedZone() {
    final GeofenceZone? zone = _selectedZone();
    if (zone == null || !zone.hasPolygon) {
      return;
    }
    final List<GeoPoint> points = zone.polygon;
    if (points.isEmpty) {
      return;
    }

    double latSum = 0;
    double lonSum = 0;
    for (final GeoPoint point in points) {
      latSum += point.latitude;
      lonSum += point.longitude;
    }
    final LatLng center = LatLng(latSum / points.length, lonSum / points.length);

    try {
      _zonesMapController.move(center, 14);
    } catch (_) {
      // Ignore map timing issues before first layout.
    }
  }

  Future<void> _associateSelectedZone() async {
    final int? zoneId = _selectedZoneId;
    final int? vehicleId = _selectedVehicleId;
    if (zoneId == null || vehicleId == null) {
      _showMessage('Selecciona geocerco y vehiculo.');
      return;
    }

    setState(() => _saving = true);
    try {
      final ActionResult result = await widget.controller.associateGeofence(
        idMovil: vehicleId,
        idGeofence: zoneId,
        useSchedule: _useSchedule,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
      );
      if (!mounted) {
        return;
      }
      _showMessage(result.ok ? 'Geocerco asociado correctamente.' : result.message);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo asociar: $ex');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final TimeOfDay initial = start ? _startTime : _endTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _addDraftPoint(TapPosition _, LatLng point) {
    setState(() {
      _draftPolygon.add(GeoPoint(latitude: point.latitude, longitude: point.longitude));
    });
  }

  Future<void> _createDraftZone() async {
    final String name = _newZoneNameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Ingresa nombre de geocerco.');
      return;
    }
    if (_draftPolygon.length < 3) {
      _showMessage('Agrega al menos 3 puntos en el mapa.');
      return;
    }

    setState(() => _saving = true);
    try {
      final ActionResult result = await widget.controller.createGeofence(
        name: name,
        polygon: _draftPolygon,
      );
      if (!mounted) {
        return;
      }
      if (!result.ok) {
        _showMessage(result.message);
        return;
      }
      _showMessage('Geocerco creado.');
      setState(() {
        _newZoneNameController.clear();
        _draftPolygon.clear();
      });
      await _loadData();
    } catch (ex) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo crear geocerco: $ex');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Geocercas'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Visualizar'),
              Tab(text: 'Crear'),
            ],
          ),
          actions: <Widget>[
            IconButton(
              onPressed: _loading ? null : _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        body: TabBarView(
          children: <Widget>[
            _buildViewTab(),
            _buildCreateTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab() {
    if (_loading && _zones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: <Widget>[
        if ((_error ?? '').isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xfffff3cd),
            padding: const EdgeInsets.all(10),
            child: Text(_error!),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    value: _selectedZoneId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Geocerco',
                    ),
                    items: _zones
                        .map(
                          (GeofenceZone zone) => DropdownMenuItem<int>(
                            value: zone.id,
                            child: Text('${zone.name} (${zone.associatedVehicles})'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (int? value) {
                            setState(() => _selectedZoneId = value);
                            _focusSelectedZone();
                          },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _selectedVehicleId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Vehiculo para asociar',
                    ),
                    items: _vehicles
                        .map(
                          (VehicleRef item) => DropdownMenuItem<int>(
                            value: item.idMovil,
                            child: Text(item.plate),
                          ),
                        )
                        .toList(),
                    onChanged: _saving ? null : (int? value) => setState(() => _selectedVehicleId = value),
                  ),
                  CheckboxListTile(
                    value: _useSchedule,
                    onChanged: _saving ? null : (bool? value) => setState(() => _useSchedule = value ?? false),
                    title: const Text('Asociar por horario'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_useSchedule)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : () => _pickTime(start: true),
                            icon: const Icon(Icons.schedule),
                            label: Text('Inicio ${_formatTime(_startTime)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : () => _pickTime(start: false),
                            icon: const Icon(Icons.schedule),
                            label: Text('Fin ${_formatTime(_endTime)}'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _associateSelectedZone,
                      icon: const Icon(Icons.link),
                      label: const Text('Asociar geocerco a vehiculo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _zonesMapController,
                options: const MapOptions(
                  initialCenter: LatLng(4.711, -74.0721),
                  initialZoom: 5.8,
                  minZoom: 3,
                  maxZoom: 18,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'co.com.satelitrack.native',
                  ),
                  PolygonLayer(
                    polygons: _zones
                        .where((GeofenceZone z) => z.hasPolygon)
                        .map(
                          (GeofenceZone zone) => Polygon(
                            points: zone.polygon
                                .map((GeoPoint p) => LatLng(p.latitude, p.longitude))
                                .toList(),
                            color: zone.id == _selectedZoneId
                                ? const Color(0x553f51b5)
                                : const Color(0x334caf50),
                            borderStrokeWidth: zone.id == _selectedZoneId ? 3 : 2,
                            borderColor: zone.id == _selectedZoneId
                                ? const Color(0xff3f51b5)
                                : const Color(0xff2e7d32),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateTab() {
    final List<LatLng> draftPoints = _draftPolygon
        .map((GeoPoint p) => LatLng(p.latitude, p.longitude))
        .toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _newZoneNameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Nombre del geocerco',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving || _draftPolygon.isEmpty
                              ? null
                              : () => setState(() => _draftPolygon.removeLast()),
                          icon: const Icon(Icons.undo),
                          label: const Text('Deshacer punto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving || _draftPolygon.isEmpty
                              ? null
                              : () => setState(() => _draftPolygon.clear()),
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _createDraftZone,
                      icon: const Icon(Icons.save),
                      label: Text('Guardar geocerco (${_draftPolygon.length} puntos)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: draftPoints.isNotEmpty ? draftPoints.first : const LatLng(4.711, -74.0721),
                  initialZoom: draftPoints.isNotEmpty ? 12 : 5.8,
                  minZoom: 3,
                  maxZoom: 18,
                  onTap: _saving ? null : _addDraftPoint,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'co.com.satelitrack.native',
                  ),
                  if (draftPoints.length >= 3)
                    PolygonLayer(
                      polygons: <Polygon>[
                        Polygon(
                          points: draftPoints,
                          color: const Color(0x552196f3),
                          borderStrokeWidth: 2.2,
                          borderColor: const Color(0xff1976d2),
                        ),
                      ],
                    ),
                  PolylineLayer(
                    polylines: <Polyline>[
                      Polyline(
                        points: draftPoints,
                        strokeWidth: 2,
                        color: const Color(0xff1976d2),
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      for (int i = 0; i < draftPoints.length; i++)
                        Marker(
                          point: draftPoints[i],
                          width: 26,
                          height: 26,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xffd32f2f),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatTime(TimeOfDay value) {
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute:00';
}
