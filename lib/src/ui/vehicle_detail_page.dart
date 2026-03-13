import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';
import '../theme/app_palette.dart';
import 'commands_page.dart';

class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage({
    super.key,
    required this.controller,
    required this.initialPosition,
  });

  final AppController controller;
  final VehiclePosition initialPosition;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  late VehiclePosition _item;
  bool _loading = false;
  String? _error;
  int? _vehicleId;

  @override
  void initState() {
    super.initState();
    _item = widget.initialPosition;
    unawaited(_resolveVehicleId());
  }

  Future<void> _resolveVehicleId() async {
    try {
      final List<VehicleRef> vehicles = await widget.controller.loadVehicles();
      if (!mounted) {
        return;
      }
      for (final VehicleRef vehicle in vehicles) {
        if (vehicle.plate.toUpperCase() == _item.plate.toUpperCase()) {
          setState(() => _vehicleId = vehicle.idMovil);
          return;
        }
      }
    } catch (_) {
      // Optional enhancement; keep detail available even if this lookup fails.
    }
  }

  Future<void> _refreshVehicle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.controller.refreshDashboard(silent: true);
      if (!mounted) {
        return;
      }
      final String plate = _item.plate.toUpperCase();
      for (final VehiclePosition current in widget.controller.positions) {
        if (current.plate.toUpperCase() == plate) {
          setState(() => _item = current);
          break;
        }
      }
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

  void _openCommands() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommandsPage(
          controller: widget.controller,
          initialVehicleId: _vehicleId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = _item.hasCoordinate
        ? LatLng(_item.latitude, _item.longitude)
        : const LatLng(4.711, -74.0721);
    final bool canUseCommands = widget.controller.isModuleEnabled('commands');

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle ${_item.plate}'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _refreshVehicle,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          if ((_error ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _item.hasCoordinate ? 13 : 5.5,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'co.com.satelitrack.native',
                  ),
                  if (_item.hasCoordinate)
                    MarkerLayer(
                      markers: <Marker>[
                        Marker(
                          point: center,
                          width: 120,
                          height: 54,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppPalette.borderSoft),
                                ),
                                child: Text(
                                  _item.plate,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ),
                              const Icon(Icons.place, color: Color(0xffd32f2f)),
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _item.position,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _DataBadge(label: 'Fecha', value: formatBackendDateTime(_item.reportDate)),
                      _DataBadge(label: 'Ign', value: _item.ignitionLabel),
                      _DataBadge(label: 'Velocidad', value: _item.speed),
                      _DataBadge(label: 'Km dia', value: _item.kmDay),
                      _DataBadge(label: 'Km total', value: _item.kmTotal),
                      _DataBadge(label: 'Horometro', value: _item.horometerLabel),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _refreshVehicle,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ),
              if (canUseCommands) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _openCommands,
                    icon: const Icon(Icons.terminal),
                    label: const Text('Comandos'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DataBadge extends StatelessWidget {
  const _DataBadge({
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
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffdde3ee)),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
