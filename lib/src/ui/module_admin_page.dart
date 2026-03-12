import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';

class ModuleAdminPage extends StatefulWidget {
  const ModuleAdminPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ModuleAdminPage> createState() => _ModuleAdminPageState();
}

class _ModuleAdminPageState extends State<ModuleAdminPage> {
  final TextEditingController _targetClientController = TextEditingController();

  bool _loading = false;
  String? _savingModuleKey;
  String? _error;
  MobileModuleAccess? _config;

  static const List<String> _orderedKeys = <String>[
    'map',
    'alarms',
    'commands',
    'geofences',
    'reports',
    'checklist',
  ];

  static const Map<String, String> _labels = <String, String>{
    'map': 'Mapa',
    'alarms': 'Alarmas',
    'commands': 'Comandos',
    'geofences': 'Geocercas',
    'reports': 'Reportes',
    'checklist': 'Checklist',
  };

  @override
  void initState() {
    super.initState();
    final MobileModuleAccess? current = widget.controller.moduleAccess;
    if (current != null && current.clientId > 0) {
      _targetClientController.text = current.clientId.toString();
      _config = current;
    }
    unawaited(_loadConfig());
  }

  @override
  void dispose() {
    _targetClientController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig({int? targetClientId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final MobileModuleAccess? access = await widget.controller.loadModuleAccess(
        targetClientId: targetClientId,
        silent: true,
      );
      if (!mounted) {
        return;
      }

      if (access == null) {
        setState(() => _error = 'No fue posible cargar la configuracion de modulos.');
      } else {
        setState(() {
          _config = access;
          if (_targetClientController.text.trim().isEmpty) {
            _targetClientController.text = access.clientId.toString();
          }
        });
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

  Future<void> _applyTargetClient() async {
    final int? target = _readTargetClientId();
    if (target == null) {
      _showMessage('Ingresa un id de cliente valido.');
      return;
    }

    await _loadConfig(targetClientId: target);
  }

  Future<void> _toggleModule(String moduleKey, bool enabled) async {
    final MobileModuleAccess? cfg = _config;
    if (cfg == null) {
      return;
    }

    if (!cfg.canManageModules) {
      _showMessage('No tienes permisos para administrar modulos.');
      return;
    }

    setState(() => _savingModuleKey = moduleKey);

    final int? targetClientId = _readTargetClientId() ?? cfg.clientId;
    final ActionResult result = await widget.controller.updateModuleAccess(
      module: moduleKey,
      enabled: enabled,
      targetClientId: targetClientId,
    );

    if (!mounted) {
      return;
    }

    if (result.ok) {
      setState(() => _config = widget.controller.moduleAccess);
      _showMessage('Modulo actualizado.');
    } else {
      _showMessage(result.message);
    }

    setState(() => _savingModuleKey = null);
  }

  int? _readTargetClientId() {
    final String raw = _targetClientController.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final MobileModuleAccess? cfg = _config;
    final bool canManage = cfg?.canManageModules ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador app'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _loadConfig,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if ((_error ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          if (cfg == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Sin datos de configuracion de modulos.'),
              ),
            )
          else ...<Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Cliente actual: ${cfg.clientId}'),
                    const SizedBox(height: 4),
                    Text('Permiso admin: ${canManage ? 'SI' : 'NO'}'),
                    const SizedBox(height: 4),
                    Text('Tabla de modulos: ${cfg.tableReady ? 'LISTA' : 'PENDIENTE'}'),
                  ],
                ),
              ),
            ),
            if (canManage)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _targetClientController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Id cliente',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _loading ? null : _applyTargetClient,
                        child: const Text('Cargar'),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Column(
                children: _orderedKeys
                    .map(
                      (String key) => SwitchListTile(
                        title: Text(_labels[key] ?? key),
                        value: cfg.isEnabled(key),
                        onChanged: (!canManage || _savingModuleKey != null)
                            ? null
                            : (bool value) => _toggleModule(key, value),
                        secondary: _savingModuleKey == key
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                      ),
                    )
                    .toList(),
              ),
            ),
            if (!cfg.tableReady)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Para persistir cambios ejecuta app2025/docs/MOBILE_APP_ADMIN_SETUP.sql en PostgreSQL.',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
