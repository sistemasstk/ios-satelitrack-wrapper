import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../config/app_config.dart';
import '../models/domain_models.dart';
import '../theme/app_palette.dart';
import 'alarms_page.dart';
import 'checklist_page.dart';
import 'commands_page.dart';
import 'geofences_page.dart';
import 'map_page.dart';
import 'media_evidence_page.dart';
import 'module_admin_page.dart';
import 'vehicle_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  String _plateQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final List<VehiclePosition> allPositions = controller.positions;
    final List<VehiclePosition> filteredPositions = _filterByPlate(allPositions);
    final bool hasData = allPositions.isNotEmpty;
    final bool hasFilter = _plateQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
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
        child: _buildBody(
          hasData: hasData,
          allPositions: allPositions,
          filteredPositions: filteredPositions,
          hasFilter: hasFilter,
        ),
      ),
    );
  }

  List<VehiclePosition> _filterByPlate(List<VehiclePosition> source) {
    final String query = _plateQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return source;
    }
    return source.where((VehiclePosition item) => item.plate.toLowerCase().contains(query)).toList();
  }

  Widget _buildBody({
    required bool hasData,
    required List<VehiclePosition> allPositions,
    required List<VehiclePosition> filteredPositions,
    required bool hasFilter,
  }) {
    final AppController controller = widget.controller;

    if (controller.loadingDashboard && !hasData) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (!hasData && (controller.errorMessage ?? '').isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: <Widget>[
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Buscar placa',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _plateQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _plateQuery = '');
                        },
                      ),
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (String value) => setState(() => _plateQuery = value),
            ),
          ),
        ),
        _SummaryCard(
          vehiclesCount: controller.vehiclesCount,
          username: controller.session?.username ?? '',
          loading: controller.loadingDashboard,
          controller: controller,
        ),
        if (hasFilter && filteredPositions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No hay vehiculos para esa placa.'),
            ),
          ),
        ...filteredPositions.map(
          (VehiclePosition item) => _PositionCard(
            item: item,
            controller: controller,
          ),
        ),
      ],
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
    final List<_ActionItem> actions = _buildActions(context);

    return Card(
      color: AppPalette.softGreenSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              username.isEmpty ? 'Sesion activa' : 'Hola, $username',
              style: const TextStyle(fontSize: 14, color: AppPalette.midGreen),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Icon(Icons.local_shipping_outlined, color: AppPalette.deepGreen),
                const SizedBox(width: 8),
                Text(
                  '$vehiclesCount vehiculos activos',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.deepGreen,
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
            _ActionGrid(actions: actions),
            if (actions.isEmpty) ...<Widget>[
              const SizedBox(height: 6),
              const Text(
                'No hay modulos habilitados para esta cuenta.',
                style: TextStyle(fontSize: 12, color: Color(0xff607d8b)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_ActionItem> _buildActions(BuildContext context) {
    final List<_ActionItem> items = <_ActionItem>[];

    if (controller.isModuleEnabled('map', fallback: true)) {
      items.add(
        _ActionItem(
          icon: Icons.map_outlined,
          label: 'Mapa',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MapPage(controller: controller),
              ),
            );
          },
        ),
      );
    }

    if (controller.isModuleEnabled('alarms', fallback: true)) {
      items.add(
        _ActionItem(
          icon: Icons.warning_amber_rounded,
          label: 'Alarmas',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlarmsPage(controller: controller),
              ),
            );
          },
        ),
      );
    }

    if (controller.isModuleEnabled('commands')) {
      items.add(
        _ActionItem(
          icon: Icons.terminal,
          label: 'Comandos',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommandsPage(controller: controller),
              ),
            );
          },
        ),
      );
    }

    if (controller.isModuleEnabled('geofences', fallback: true)) {
      items.add(
        _ActionItem(
          icon: Icons.crop_free,
          label: 'Geocercas',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GeofencesPage(controller: controller),
              ),
            );
          },
        ),
      );
    }

    if (controller.isModuleEnabled('reports', fallback: true)) {
      items.add(
        _ActionItem(
          icon: Icons.history_edu_outlined,
          label: 'Reportes',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaEvidencePage(controller: controller),
              ),
            );
          },
        ),
      );
    }

    if (controller.isModuleEnabled('checklist', fallback: true)) {
      items.add(
        _ActionItem(
          icon: Icons.checklist_rtl_outlined,
          label: 'Checklist',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChecklistPage(controller: controller),
              ),
            );
          },
        ),
      );
    }

    if (controller.canManageModules) {
      items.add(
        _ActionItem(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Admin app',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ModuleAdminPage(controller: controller),
              ),
            );
          },
        ),
      );
    }

    return items;
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 620 ? 3 : 2;
        final double ratio = constraints.maxWidth > 620 ? 3.3 : 2.9;
        return GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: ratio,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _ActionItem item = actions[index];
            return FilledButton.tonalIcon(
              onPressed: item.onTap,
              icon: Icon(item.icon),
              label: Text(item.label),
            );
          },
        );
      },
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
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
                      child: Text(
                        formatBackendDateTime(item.reportDate),
                        style: const TextStyle(fontSize: 12),
                      ),
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
                      color: AppPalette.chipGreen,
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
