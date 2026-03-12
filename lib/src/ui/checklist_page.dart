import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  bool _loading = false;
  bool _saving = false;
  bool _loadingHistory = false;

  String? _error;

  List<ChecklistVehicle> _vehicles = const <ChecklistVehicle>[];
  List<ChecklistItemDefinition> _items = const <ChecklistItemDefinition>[];
  List<ChecklistHistoryEntry> _history = const <ChecklistHistoryEntry>[];

  int? _selectedVehicleId;
  final Map<int, bool> _itemStates = <int, bool>{};
  final Map<int, TextEditingController> _commentControllers = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialData());
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<ChecklistVehicle> vehicles = await widget.controller.loadChecklistVehicles();
      final List<ChecklistItemDefinition> items = await widget.controller.loadChecklistItems();
      final List<ChecklistHistoryEntry> history = await widget.controller.loadChecklistHistory();

      if (!mounted) {
        return;
      }

      for (final ChecklistItemDefinition item in items) {
        _itemStates.putIfAbsent(item.idItem, () => true);
        _commentControllers.putIfAbsent(item.idItem, () => TextEditingController());
      }

      setState(() {
        _vehicles = vehicles;
        _items = items;
        _history = history;
        if (_selectedVehicleId == null && vehicles.isNotEmpty) {
          _selectedVehicleId = vehicles.first.idMovil;
        } else if (_selectedVehicleId != null &&
            !vehicles.any((ChecklistVehicle v) => v.idMovil == _selectedVehicleId)) {
          _selectedVehicleId = vehicles.isEmpty ? null : vehicles.first.idMovil;
        }
      });
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

  Future<void> _reloadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final List<ChecklistHistoryEntry> history = await widget.controller.loadChecklistHistory();
      if (!mounted) {
        return;
      }
      setState(() => _history = history);
    } catch (ex) {
      if (mounted) {
        _showMessage('No se pudo cargar historial: $ex');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _saveChecklist() async {
    final int? idMovil = _selectedVehicleId;
    if (idMovil == null) {
      _showMessage('Selecciona un vehiculo.');
      return;
    }

    if (_items.isEmpty) {
      _showMessage('No hay items configurados para checklist.');
      return;
    }

    final Map<String, dynamic> checks = <String, dynamic>{};
    for (final ChecklistItemDefinition item in _items) {
      checks['item_${item.idItem}'] = <String, dynamic>{
        'buen_estado': _itemStates[item.idItem] ?? true,
        'comentario': _commentControllers[item.idItem]?.text.trim() ?? '',
      };
    }

    setState(() => _saving = true);
    try {
      final ActionResult result = await widget.controller.saveChecklist(
        idMovil: idMovil,
        checks: checks,
      );
      if (!mounted) {
        return;
      }
      if (result.ok) {
        _showMessage('Checklist guardado correctamente.');
        for (final ChecklistItemDefinition item in _items) {
          _itemStates[item.idItem] = true;
          _commentControllers[item.idItem]?.clear();
        }
        unawaited(_reloadHistory());
      } else {
        _showMessage(result.message);
      }
    } catch (ex) {
      if (mounted) {
        _showMessage('No se pudo guardar checklist: $ex');
      }
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
          title: const Text('Checklist preoperativo'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _loadInitialData,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Nuevo checklist'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: <Widget>[
                  _buildFormTab(),
                  _buildHistoryTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildFormTab() {
    return ListView(
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                DropdownButtonFormField<int>(
                  value: _selectedVehicleId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Vehiculo',
                  ),
                  items: _vehicles
                      .map(
                        (ChecklistVehicle item) => DropdownMenuItem<int>(
                          value: item.idMovil,
                          child: Text(item.plate),
                        ),
                      )
                      .toList(),
                  onChanged: _saving ? null : (int? value) => setState(() => _selectedVehicleId = value),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveChecklist,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Guardar checklist'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No hay items configurados.'),
            ),
          )
        else
          ..._items.map(_buildChecklistItemCard),
      ],
    );
  }

  Widget _buildChecklistItemCard(ChecklistItemDefinition item) {
    final TextEditingController commentController =
        _commentControllers.putIfAbsent(item.idItem, () => TextEditingController());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _itemStates[item.idItem] ?? true,
                  onChanged: _saving
                      ? null
                      : (bool value) {
                          setState(() => _itemStates[item.idItem] = value);
                        },
                ),
              ],
            ),
            Text(
              (_itemStates[item.idItem] ?? true) ? 'Estado: OK' : 'Estado: Falla',
              style: TextStyle(
                color: (_itemStates[item.idItem] ?? true)
                    ? const Color(0xff2e7d32)
                    : const Color(0xffc62828),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              enabled: !_saving,
              maxLength: 250,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Comentario (opcional)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty && !_loadingHistory) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No hay checklist registrados.'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _reloadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar historial'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ..._history.map(
            (ChecklistHistoryEntry item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(item.plate),
                subtitle: Text(item.date),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('OK ${item.totalOk}/${item.totalItems}'),
                    Text('Fallas ${item.totalFallas}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
