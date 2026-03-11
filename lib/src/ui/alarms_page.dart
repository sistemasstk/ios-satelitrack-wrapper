import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';

class AlarmsPage extends StatefulWidget {
  const AlarmsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> {
  bool _loadingPending = false;
  bool _loadingHistory = false;
  bool _loadingVehicles = false;

  List<PendingAlarm> _pending = const <PendingAlarm>[];
  List<AlarmHistoryItem> _history = const <AlarmHistoryItem>[];
  List<VehicleRef> _vehicles = const <VehicleRef>[];
  int? _selectedVehicleId;
  DateTime _from = _atStartOfDay(DateTime.now());
  DateTime _to = DateTime.now();
  String? _errorPending;
  String? _errorHistory;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    await Future.wait(<Future<void>>[
      _loadPending(),
      _loadVehicles(),
    ]);
  }

  Future<void> _loadVehicles() async {
    setState(() => _loadingVehicles = true);
    try {
      final List<VehicleRef> items = await widget.controller.loadVehicles();
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicles = items;
        if (_selectedVehicleId != null &&
            !items.any((VehicleRef vehicle) => vehicle.idMovil == _selectedVehicleId)) {
          _selectedVehicleId = null;
        }
        if (_selectedVehicleId == null && items.isNotEmpty) {
          _selectedVehicleId = items.first.idMovil;
        }
      });
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() => _errorHistory = ex.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingVehicles = false);
      }
    }
  }

  Future<void> _loadPending() async {
    setState(() {
      _loadingPending = true;
      _errorPending = null;
    });
    try {
      final List<PendingAlarm> items = await widget.controller.loadPendingAlarms();
      if (!mounted) {
        return;
      }
      setState(() => _pending = items);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() => _errorPending = ex.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingPending = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    final int? idMovil = _selectedVehicleId;
    if (idMovil == null) {
      return;
    }

    setState(() {
      _loadingHistory = true;
      _errorHistory = null;
      _history = const <AlarmHistoryItem>[];
    });

    try {
      final List<AlarmHistoryItem> items = await widget.controller.loadAlarmHistory(
        idMovil: idMovil,
        from: _from,
        to: _to,
      );
      if (!mounted) {
        return;
      }
      setState(() => _history = items);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() => _errorHistory = ex.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _pickFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _from = _atStartOfDay(picked));
  }

  Future<void> _pickToDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _to = _atEndOfDay(picked));
  }

  Future<void> _openAttendDialog(PendingAlarm alarm) async {
    final TextEditingController noteController = TextEditingController();
    bool similar = false;

    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setLocalState) {
            return AlertDialog(
              title: Text('Atender alarma ${alarm.plate}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(alarm.event),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Novedad',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: similar,
                    onChanged: (bool? value) => setLocalState(() => similar = value ?? false),
                    title: const Text('Aplicar a eventos similares'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Atender'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      noteController.dispose();
      return;
    }

    final String note = noteController.text.trim();
    noteController.dispose();
    if (note.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes registrar una novedad.')),
      );
      return;
    }

    try {
      final ActionResult result = await widget.controller.markAlarmAsAttended(
        eventId: alarm.eventId,
        note: note,
        similar: similar,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.ok ? 'Alarma atendida.' : result.message)),
      );
      if (result.ok) {
        await _loadPending();
      }
    } catch (ex) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo atender la alarma: $ex')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alarmas'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Pendientes'),
              Tab(text: 'Historial'),
            ],
          ),
          actions: <Widget>[
            IconButton(
              onPressed: _loadPending,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar pendientes',
            ),
          ],
        ),
        body: TabBarView(
          children: <Widget>[
            _buildPendingTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }

    if ((_errorPending ?? '').isNotEmpty) {
      return _InfoState(message: _errorPending!, buttonText: 'Reintentar', onPressed: _loadPending);
    }

    if (_pending.isEmpty) {
      return _InfoState(message: 'No hay alarmas pendientes.', buttonText: 'Actualizar', onPressed: _loadPending);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pending.length,
      itemBuilder: (BuildContext context, int index) {
        final PendingAlarm alarm = _pending[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text('${alarm.plate} - ${alarm.event}'),
            subtitle: Text('${alarm.receivedAt}\n${alarm.position}', maxLines: 3, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            trailing: FilledButton(
              onPressed: () => _openAttendDialog(alarm),
              child: const Text('Atender'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final Set<int> knownVehicleIds = _vehicles.map((VehicleRef v) => v.idMovil).toSet();
    final int? selectedVehicleId =
        (_selectedVehicleId != null && knownVehicleIds.contains(_selectedVehicleId))
            ? _selectedVehicleId
            : null;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    value: selectedVehicleId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Vehiculo',
                    ),
                    items: _vehicles
                        .map(
                          (VehicleRef item) => DropdownMenuItem<int>(
                            value: item.idMovil,
                            child: Text(item.plate),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingVehicles
                        ? null
                        : (int? value) {
                            setState(() => _selectedVehicleId = value);
                          },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromDate,
                          icon: const Icon(Icons.date_range),
                          label: Text('Desde: ${_fmtDate(_from)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickToDate,
                          icon: const Icon(Icons.date_range),
                          label: Text('Hasta: ${_fmtDate(_to)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_selectedVehicleId == null || _loadingHistory) ? null : _loadHistory,
                      icon: const Icon(Icons.search),
                      label: const Text('Consultar historial'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildHistoryResults(),
        ),
      ],
    );
  }

  Widget _buildHistoryResults() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if ((_errorHistory ?? '').isNotEmpty) {
      return _InfoState(message: _errorHistory!, buttonText: 'Reintentar', onPressed: _loadHistory);
    }
    if (_history.isEmpty) {
      return const Center(
        child: Text('Sin datos. Selecciona un vehiculo y consulta el rango.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      itemCount: _history.length,
      itemBuilder: (BuildContext context, int index) {
        final AlarmHistoryItem item = _history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(item.event),
            subtitle: Text('${item.gpsDate}\n${item.position}', maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('${item.speed} km/h', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Ign: ${item.ignition}'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final String message;
  final String buttonText;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime value) {
  final String year = value.year.toString().padLeft(4, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime _atStartOfDay(DateTime input) => DateTime(input.year, input.month, input.day);

DateTime _atEndOfDay(DateTime input) => DateTime(input.year, input.month, input.day, 23, 59, 59);
