import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../config/app_config.dart';
import '../models/domain_models.dart';
import 'alarms_page.dart';
import 'commands_page.dart';
import 'geofences_page.dart';
import 'map_page.dart';
import 'media_evidence_page.dart';
import 'panic_page.dart';
import 'vehicle_detail_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bool hasData = controller.positions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Satelitrack'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: controller.loadingDashboard ? null : () => controller.refreshDashboard(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: () => controller.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refreshDashboard(),
        child: _buildBody(hasData: hasData),
      ),
    );
  }

  Widget _buildBody({required bool hasData}) {
    if (controller.loadingDashboard && !hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasData && (controller.errorMessage ?? '').isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, size: 52, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            controller.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => controller.refreshDashboard(),
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      itemCount: controller.positions.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _SummaryCard(
            vehiclesCount: controller.vehiclesCount,
            username: controller.session?.username ?? '',
            loading: controller.loadingDashboard,
            controller: controller,
          );
        }
        final VehiclePosition item = controller.positions[index - 1];
        return _PositionCard(item: item, controller: controller);
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.vehiclesCount,
    required this.username,
    required this.loading,
    required this.controller,
  });

  final int vehiclesCount;
  final String username;
  final bool loading;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xfff5f9ff),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              username.isEmpty ? 'Sesion activa' : 'Hola, $username',
              style: const TextStyle(fontSize: 14, color: Color(0xff35507f)),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Icon(Icons.local_shipping_outlined, color: Color(0xff022a73)),
                const SizedBox(width: 8),
                Text(
                  '$vehiclesCount vehiculos activos',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff022a73),
                  ),
                ),
                if (loading) ...<Widget>[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MapPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Mapa'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlarmsPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Alarmas'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CommandsPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.terminal),
                  label: const Text('Comandos'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GeofencesPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.crop_free),
                  label: const Text('Geocercas'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MediaEvidencePage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Evidencias'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffc62828),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PanicPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.warning_amber),
                  label: const Text('Panico'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.item,
    required this.controller,
  });

  final VehiclePosition item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final Color freshnessColor = _freshnessColor(item.reportDate);
    final String imageUrl = AppConfig.resolve('assets/img/moviles/${item.imageName}').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VehicleDetailPage(
                controller: controller,
                initialPosition: item,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.plate,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: freshnessColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(item.reportDate, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Image.network(
                    imageUrl,
                    width: 48,
                    height: 28,
                    errorBuilder: (_, __, ___) => const Icon(Icons.directions_car),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xffeef4ff),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Ign: ${item.ignitionLabel}'),
                  ),
                  const SizedBox(width: 8),
                  Text(item.speed),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.position,
                style: const TextStyle(fontSize: 13.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  _MetricChip(label: 'Km dia', value: item.kmDay),
                  _MetricChip(label: 'Km total', value: item.kmTotal),
                  _MetricChip(label: 'Horometro', value: item.horometerLabel),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Toca para ver detalle',
                style: TextStyle(fontSize: 12, color: Color(0xff607d8b)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffdce2ec)),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}

Color _freshnessColor(String rawDate) {
  final DateTime? report = _parseBackendDate(rawDate);
  if (report == null) {
    return const Color(0xfff8d7da);
  }

  final int diffMinutes = DateTime.now().difference(report).inMinutes;
  if (diffMinutes < 60) {
    return const Color(0xffc1ff96);
  }
  if (diffMinutes < 180) {
    return const Color(0xffe8952e);
  }
  if (diffMinutes < 360) {
    return const Color(0xffffdb5b);
  }
  return const Color(0xffff5e51);
}

DateTime? _parseBackendDate(String rawDate) {
  final String normalized = rawDate.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final DateTime? direct = DateTime.tryParse(normalized);
  if (direct != null) {
    return direct;
  }

  return DateTime.tryParse(normalized.replaceFirst(' ', 'T'));
}
