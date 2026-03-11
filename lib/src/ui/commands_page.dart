import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/domain_models.dart';

class CommandsPage extends StatefulWidget {
  const CommandsPage({
    super.key,
    required this.controller,
    this.initialVehicleId,
  });

  final AppController controller;
  final int? initialVehicleId;

  @override
  State<CommandsPage> createState() => _CommandsPageState();
}

class _CommandsPageState extends State<CommandsPage> {
  final TextEditingController _customCommandController = TextEditingController();

  bool _loadingVehicles = false;
  bool _sending = false;
  bool _polling = false;
  int _pollGeneration = 0;
  int? _selectedVehicleId;
  List<VehicleRef> _vehicles = const <VehicleRef>[];
  String? _feedback;
  String? _commandReply;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.initialVehicleId;
    unawaited(_loadVehicles());
  }

  @override
  void dispose() {
    _customCommandController.dispose();
    _pollGeneration++;
    super.dispose();
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
        _selectedVehicleId ??= widget.initialVehicleId;
        if (_selectedVehicleId != null &&
            !items.any((VehicleRef vehicle) => vehicle.idMovil == _selectedVehicleId)) {
          _selectedVehicleId = null;
        }
        _selectedVehicleId ??= items.isEmpty ? null : items.first.idMovil;
      });
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() => _feedback = 'No se pudo cargar vehiculos: $ex');
    } finally {
      if (mounted) {
        setState(() => _loadingVehicles = false);
      }
    }
  }

  Future<void> _sendStandardCommand(int commandType) async {
    final int? idMovil = _selectedVehicleId;
    if (idMovil == null) {
      _showMessage('Selecciona un vehiculo.');
      return;
    }

    setState(() {
      _sending = true;
      _feedback = null;
      _commandReply = null;
    });

    try {
      final DateTime sentAt = DateTime.now();
      final ActionResult result = await widget.controller.sendRemoteCommand(
        idMovil: idMovil,
        commandType: commandType,
      );
      if (!mounted) {
        return;
      }
      if (!result.ok) {
        setState(() {
          _sending = false;
          _feedback = result.message;
        });
        return;
      }

      setState(() {
        _feedback = 'Comando enviado. Esperando respuesta...';
      });
      await _pollForReply(idMovil: idMovil, sentAt: sentAt);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _polling = false;
        _feedback = 'Error enviando comando: $ex';
      });
    }
  }

  Future<void> _sendVideoCommand(int cameraChannel) async {
    final int? idMovil = _selectedVehicleId;
    if (idMovil == null) {
      _showMessage('Selecciona un vehiculo.');
      return;
    }

    final int unixSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String command = 'camreq:0,$cameraChannel,$unixSeconds,5';

    setState(() {
      _sending = true;
      _feedback = null;
      _commandReply = null;
    });

    try {
      final DateTime sentAt = DateTime.now();
      final ActionResult result = await widget.controller.sendVideoCommand(
        idMovil: idMovil,
        command: command,
      );
      if (!mounted) {
        return;
      }
      if (!result.ok) {
        setState(() {
          _sending = false;
          _feedback = result.message;
        });
        return;
      }

      setState(() => _feedback = 'Solicitud de video enviada. Esperando respuesta...');
      await _pollForReply(idMovil: idMovil, sentAt: sentAt);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _polling = false;
        _feedback = 'Error enviando video: $ex';
      });
    }
  }

  Future<void> _sendCustomCommand() async {
    final int? idMovil = _selectedVehicleId;
    final String command = _customCommandController.text.trim();
    if (idMovil == null) {
      _showMessage('Selecciona un vehiculo.');
      return;
    }
    if (command.isEmpty) {
      _showMessage('Ingresa un comando personalizado.');
      return;
    }

    setState(() {
      _sending = true;
      _feedback = null;
      _commandReply = null;
    });

    try {
      final DateTime sentAt = DateTime.now();
      final ActionResult result = await widget.controller.sendVideoCommand(
        idMovil: idMovil,
        command: command,
      );
      if (!mounted) {
        return;
      }
      if (!result.ok) {
        setState(() {
          _sending = false;
          _feedback = result.message;
        });
        return;
      }

      setState(() => _feedback = 'Comando personalizado enviado. Esperando respuesta...');
      await _pollForReply(idMovil: idMovil, sentAt: sentAt);
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _polling = false;
        _feedback = 'Error enviando comando: $ex';
      });
    }
  }

  Future<void> _pollForReply({
    required int idMovil,
    required DateTime sentAt,
  }) async {
    _pollGeneration++;
    final int currentGeneration = _pollGeneration;
    setState(() {
      _polling = true;
      _sending = false;
    });

    for (int i = 0; i < 24; i++) {
      if (!mounted || currentGeneration != _pollGeneration) {
        return;
      }

      final CommandReply? reply = await widget.controller.getCommandReply(
        idMovil: idMovil,
        sentAfter: sentAt,
      );
      if (!mounted || currentGeneration != _pollGeneration) {
        return;
      }
      if (reply != null && reply.response.isNotEmpty) {
        setState(() {
          _polling = false;
          _commandReply = reply.response;
          _feedback = 'Respuesta recibida ${reply.date}';
        });
        return;
      }

      await Future<void>.delayed(const Duration(seconds: 5));
    }

    if (!mounted || currentGeneration != _pollGeneration) {
      return;
    }
    setState(() {
      _polling = false;
      _feedback = 'No se recibio respuesta en 2 minutos. Puedes reintentar.';
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Set<int> knownVehicleIds = _vehicles.map((VehicleRef v) => v.idMovil).toSet();
    final int? selectedVehicleId =
        (_selectedVehicleId != null && knownVehicleIds.contains(_selectedVehicleId))
            ? _selectedVehicleId
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comandos remotos'),
        actions: <Widget>[
          IconButton(
            onPressed: _loadingVehicles ? null : _loadVehicles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Seleccion de vehiculo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedVehicleId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Placa',
                    ),
                    items: _vehicles
                        .map(
                          (VehicleRef item) => DropdownMenuItem<int>(
                            value: item.idMovil,
                            child: Text(item.plate),
                          ),
                        )
                        .toList(),
                    onChanged: _sending || _polling
                        ? null
                        : (int? value) {
                            setState(() => _selectedVehicleId = value);
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Comandos estandar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton(
                        onPressed: _sending || _polling ? null : () => _sendStandardCommand(0),
                        child: const Text('Apagado remoto'),
                      ),
                      FilledButton.tonal(
                        onPressed: _sending || _polling ? null : () => _sendStandardCommand(1),
                        child: const Text('Encendido remoto'),
                      ),
                      FilledButton.tonal(
                        onPressed: _sending || _polling ? null : () => _sendStandardCommand(2),
                        child: const Text('Activa salida 2'),
                      ),
                      FilledButton.tonal(
                        onPressed: _sending || _polling ? null : () => _sendStandardCommand(3),
                        child: const Text('Reboot'),
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Comandos de video',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: _sending || _polling ? null : () => _sendVideoCommand(1),
                        child: const Text('Video frontal'),
                      ),
                      FilledButton.tonal(
                        onPressed: _sending || _polling ? null : () => _sendVideoCommand(2),
                        child: const Text('Video interna'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customCommandController,
                    enabled: !_sending && !_polling,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Comando personalizado',
                      hintText: 'Ej: camreq:0,1,1698261928,5',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _sending || _polling ? null : _sendCustomCommand,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar personalizado'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_sending || _polling || (_feedback ?? '').isNotEmpty || (_commandReply ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          'Estado',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        if (_sending || _polling)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if ((_feedback ?? '').isNotEmpty) Text(_feedback!),
                    if ((_commandReply ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffdce2ec)),
                        ),
                        child: Text(
                          _commandReply!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
