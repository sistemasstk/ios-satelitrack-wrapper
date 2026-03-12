import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../config/app_config.dart';
import '../models/domain_models.dart';

enum _ReportType {
  history,
  evidence,
  alarms,
}

class MediaEvidencePage extends StatefulWidget {
  const MediaEvidencePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<MediaEvidencePage> createState() => _MediaEvidencePageState();
}

class _MediaEvidencePageState extends State<MediaEvidencePage> {
  bool _loadingVehicles = false;
  bool _loadingMedia = false;
  List<VehicleRef> _vehicles = const <VehicleRef>[];
  List<TravelHistoryItem> _historyItems = const <TravelHistoryItem>[];
  List<MediaEvidence> _items = const <MediaEvidence>[];
  List<AlarmHistoryItem> _alarmItems = const <AlarmHistoryItem>[];
  int? _selectedVehicleId;
  _ReportType _reportType = _ReportType.history;
  DateTime _from = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _to = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
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
        if (_selectedVehicleId == null && vehicles.isNotEmpty) {
          _selectedVehicleId = vehicles.first.idMovil;
        } else if (_selectedVehicleId != null &&
            !vehicles.any((VehicleRef v) => v.idMovil == _selectedVehicleId)) {
          _selectedVehicleId = vehicles.isEmpty ? null : vehicles.first.idMovil;
        }
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
    setState(() => _from = DateTime(picked.year, picked.month, picked.day, 0, 0, 0));
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
    setState(() => _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
  }

  Future<void> _loadMedia() async {
    final int? idMovil = _selectedVehicleId;
    if (idMovil == null) {
      _showMessage('Selecciona un vehiculo.');
      return;
    }
    if (_from.isAfter(_to)) {
      _showMessage('La fecha inicial no puede ser mayor a la fecha final.');
      return;
    }

    setState(() {
      _loadingMedia = true;
      _error = null;
      _historyItems = const <TravelHistoryItem>[];
      _items = const <MediaEvidence>[];
      _alarmItems = const <AlarmHistoryItem>[];
    });
    try {
      if (_reportType == _ReportType.history) {
        final List<TravelHistoryItem> items = await widget.controller.loadTravelHistory(
          idMovil: idMovil,
          from: _from,
          to: _to,
        );
        if (!mounted) {
          return;
        }
        setState(() => _historyItems = items);
      } else if (_reportType == _ReportType.evidence) {
        final List<MediaEvidence> items = await widget.controller.loadMediaEvidence(
          idMovil: idMovil,
          from: _from,
          to: _to,
        );
        if (!mounted) {
          return;
        }
        setState(() => _items = items);
      } else {
        final List<AlarmHistoryItem> items = await widget.controller.loadAlarmHistory(
          idMovil: idMovil,
          from: _from,
          to: _to,
        );
        if (!mounted) {
          return;
        }
        setState(() => _alarmItems = items);
      }
    } catch (ex) {
      if (!mounted) {
        return;
      }
      setState(() => _error = ex.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingMedia = false);
      }
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('URL invalida.');
      return;
    }

    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showMessage('No fue posible abrir el enlace.');
    }
  }

  void _showImagePreview(String url) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No se pudo cargar la imagen.'),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes / Historial'),
        actions: <Widget>[
          IconButton(
            onPressed: _loadingVehicles ? null : _loadVehicles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    DropdownButtonFormField<_ReportType>(
                      value: _reportType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Tipo de informe',
                      ),
                      items: const <DropdownMenuItem<_ReportType>>[
                        DropdownMenuItem<_ReportType>(
                          value: _ReportType.history,
                          child: Text('Historial de recorrido'),
                        ),
                        DropdownMenuItem<_ReportType>(
                          value: _ReportType.evidence,
                          child: Text('Evidencias (foto/video)'),
                        ),
                        DropdownMenuItem<_ReportType>(
                          value: _ReportType.alarms,
                          child: Text('Alarmas'),
                        ),
                      ],
                      onChanged: _loadingMedia
                          ? null
                          : (_ReportType? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _reportType = value;
                                _historyItems = const <TravelHistoryItem>[];
                                _items = const <MediaEvidence>[];
                                _alarmItems = const <AlarmHistoryItem>[];
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedVehicleId,
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
                      onChanged: _loadingVehicles || _loadingMedia
                          ? null
                          : (int? value) => setState(() => _selectedVehicleId = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromDate,
                            icon: const Icon(Icons.date_range),
                            label: Text('Desde ${_fmtDate(_from)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickToDate,
                            icon: const Icon(Icons.date_range),
                            label: Text('Hasta ${_fmtDate(_to)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loadingMedia ? null : _loadMedia,
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
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }

    if ((_error ?? '').isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_reportType == _ReportType.history && _historyItems.isEmpty) {
      return const Center(
        child: Text('Sin resultados. Ajusta filtros y consulta.'),
      );
    }

    if (_reportType == _ReportType.evidence && _items.isEmpty) {
      return const Center(
        child: Text('Sin resultados. Ajusta filtros y consulta.'),
      );
    }

    if (_reportType == _ReportType.alarms && _alarmItems.isEmpty) {
      return const Center(
        child: Text('Sin resultados. Ajusta filtros y consulta.'),
      );
    }

    if (_reportType == _ReportType.history) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _historyItems.length,
        itemBuilder: (BuildContext context, int index) {
          final TravelHistoryItem item = _historyItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.alt_route),
              title: Text(item.gpsDate),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 2),
                  Text(item.position, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Velocidad: ${item.speed} km/h  |  Ignicion: ${item.ignition}'),
                ],
              ),
              trailing: item.hasCoordinate
                  ? IconButton(
                      tooltip: 'Ver mapa',
                      onPressed: () => _openExternalUrl(
                        'https://www.openstreetmap.org/?mlat=${item.latitude}&mlon=${item.longitude}#map=16/${item.latitude}/${item.longitude}',
                      ),
                      icon: const Icon(Icons.map_outlined),
                    )
                  : null,
            ),
          );
        },
      );
    }

    if (_reportType == _ReportType.alarms) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _alarmItems.length,
        itemBuilder: (BuildContext context, int index) {
          final AlarmHistoryItem item = _alarmItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(item.event),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(item.gpsDate),
                  Text(item.position, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('Ign: ${item.ignition}'),
                  Text(item.speed),
                ],
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        final MediaEvidence item = _items[index];
        final String url = item.buildAbsoluteUrl(mediaBaseUrl: AppConfig.mediaBaseUrl);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name.isEmpty ? 'Evidencia ${item.id}' : item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('${item.endDate} - ${item.isVideo ? 'Video' : 'Foto'}'),
                const SizedBox(height: 4),
                Text(item.position, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                if (item.isImage)
                  GestureDetector(
                    onTap: () => _showImagePreview(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        height: 170,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            alignment: Alignment.center,
                            height: 120,
                            color: const Color(0xfff1f5f9),
                            child: const Text('No se pudo cargar la imagen'),
                          );
                        },
                      ),
                    ),
                  ),
                if (item.isVideo)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffdce2ec)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.videocam),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Video disponible')),
                        OutlinedButton(
                          onPressed: () => _openExternalUrl(url),
                          child: const Text('Abrir'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (item.latitude != 0 && item.longitude != 0)
                      OutlinedButton.icon(
                        onPressed: () => _openExternalUrl(
                          'https://www.openstreetmap.org/?mlat=${item.latitude}&mlon=${item.longitude}#map=16/${item.latitude}/${item.longitude}',
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Mapa'),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openExternalUrl(url),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir archivo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _fmtDate(DateTime value) {
  final String y = value.year.toString().padLeft(4, '0');
  final String m = value.month.toString().padLeft(2, '0');
  final String d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
