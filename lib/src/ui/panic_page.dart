import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';

class PanicPage extends StatefulWidget {
  const PanicPage({
    super.key,
    required this.controller,
    this.initialPlate,
  });

  final AppController controller;
  final String? initialPlate;

  @override
  State<PanicPage> createState() => _PanicPageState();
}

class _PanicPageState extends State<PanicPage> {
  bool _loadingVehicles = false;
  bool _sending = false;
  List<VehicleRef> _vehicles = const <VehicleRef>[];
  String? _selectedPlate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPlate = widget.initialPlate;
    unawaited(_loadVehicles());
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loadingVehicles = true;
      _error = null;
    });
    try {
      final List<VehicleRef> vehicles = await widget.controller.loadVehicles();
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicles = vehicles;
        if (_selectedPlate != null &&
            !vehicles.any((VehicleRef item) => item.plate.toUpperCase() == _selectedPlate!.toUpperCase())) {
          _selectedPlate = null;
        }
        _selectedPlate ??= vehicles.isEmpty ? null : vehicles.first.plate;
      });
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() => _error = ex.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingVehicles = false);
      }
    }
  }

  Future<void> _sendPanic() async {
    final String? plate = _selectedPlate;
    if (plate == null || plate.trim().isEmpty) {
      _showMessage('Selecciona una placa.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Confirmar panico'),
          content: Text('Se enviara una alerta de panico para $plate. Deseas continuar?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xffc62828)),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _sending = true);
    try {
      final ActionResult result = await widget.controller.triggerPanic(plate: plate);
      if (!mounted) {
        return;
      }
      _showMessage(result.ok ? 'Alerta de panico enviada.' : result.message);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo enviar panico: $ex');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> knownPlates = _vehicles.map((VehicleRef v) => v.plate).toSet();
    final String? selectedPlate =
        (_selectedPlate != null && knownPlates.contains(_selectedPlate))
            ? _selectedPlate
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panico'),
        actions: <Widget>[
          IconButton(
            onPressed: _loadingVehicles || _sending ? null : _loadVehicles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Card(
            color: const Color(0xfffff1f2),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Usa esta accion solo en caso de emergencia real. '
                'Genera un evento operativo inmediato.',
                style: TextStyle(color: Color(0xff7f1d1d), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if ((_error ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: selectedPlate,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Placa',
                    ),
                    items: _vehicles
                        .map(
                          (VehicleRef item) => DropdownMenuItem<String>(
                            value: item.plate,
                            child: Text(item.plate),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingVehicles || _sending
                        ? null
                        : (String? value) {
                            setState(() => _selectedPlate = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending || _loadingVehicles ? null : _sendPanic,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffc62828),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.warning),
                      label: const Text(
                        'ENVIAR PANICO',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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
