import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_palette.dart';

class LocationMapPage extends StatelessWidget {
  const LocationMapPage({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.subtitle,
    this.badges = const <String>[],
  });

  final String title;
  final String? subtitle;
  final double latitude;
  final double longitude;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final LatLng point = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          SizedBox(
            height: 360,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'co.com.satelitrack.native',
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: point,
                        width: 150,
                        height: 70,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppPalette.borderSoft),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x16000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Icon(Icons.place, color: AppPalette.markerSelected, size: 28),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _InfoChip(label: 'Latitud', value: latitude.toStringAsFixed(6)),
                      _InfoChip(label: 'Longitud', value: longitude.toStringAsFixed(6)),
                      ...badges.map(
                        (String badge) => _Badge(text: badge),
                      ),
                    ],
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
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
        color: AppPalette.softGreenSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderSoft),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.chipGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
