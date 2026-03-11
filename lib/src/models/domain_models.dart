import 'dart:convert';

class UserSession {
  const UserSession({
    required this.sessionCookie,
    required this.userType,
    required this.username,
    required this.tokenId,
    required this.tokenProvider,
    required this.tokenPlatform,
    required this.createdAtIso,
  });

  final String sessionCookie;
  final int userType;
  final String username;
  final String tokenId;
  final String tokenProvider;
  final String tokenPlatform;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionCookie': sessionCookie,
      'userType': userType,
      'username': username,
      'tokenId': tokenId,
      'tokenProvider': tokenProvider,
      'tokenPlatform': tokenPlatform,
      'createdAtIso': createdAtIso,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static UserSession? fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final UserSession session = UserSession(
        sessionCookie: asString(decoded['sessionCookie']),
        userType: asInt(decoded['userType']),
        username: asString(decoded['username']),
        tokenId: asString(decoded['tokenId'], fallback: 'vacio'),
        tokenProvider: asString(decoded['tokenProvider'], fallback: 'none'),
        tokenPlatform: asString(decoded['tokenPlatform'], fallback: 'ios'),
        createdAtIso: asString(decoded['createdAtIso']),
      );

      if (session.sessionCookie.isEmpty) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }
}

class VehiclePosition {
  const VehiclePosition({
    required this.plate,
    required this.reportDate,
    required this.ignitionLabel,
    required this.position,
    required this.speed,
    required this.kmDay,
    required this.kmTotal,
    required this.horometerLabel,
    required this.deviceId,
    required this.imageName,
    required this.latitude,
    required this.longitude,
  });

  final String plate;
  final String reportDate;
  final String ignitionLabel;
  final String position;
  final String speed;
  final String kmDay;
  final String kmTotal;
  final String horometerLabel;
  final int deviceId;
  final String imageName;
  final double latitude;
  final double longitude;

  bool get hasCoordinate => latitude != 0 && longitude != 0;

  factory VehiclePosition.fromBackend(Map<String, dynamic> row) {
    final int device = asInt(row['dispositivo']);
    final int horometerMinutes = asInt(row['horometro']);
    final String ignitionLabel;

    if (device == 38) {
      ignitionLabel = '${asString(row['bat_interna'], fallback: '0')}%';
    } else {
      ignitionLabel = asString(row['ignicion']) == '1' ? 'On' : 'Off';
    }

    final int hours = horometerMinutes ~/ 60;
    final int minutes = horometerMinutes % 60;
    final String horometer = '$hours h $minutes min';

    return VehiclePosition(
      plate: asString(row['placa']),
      reportDate: asString(row['fecha']),
      ignitionLabel: ignitionLabel,
      position: asString(row['posicion']),
      speed: '${asString(row['velocidad'], fallback: '0')} km/h',
      kmDay: '${asString(row['dist'], fallback: '0')} km',
      kmTotal: '${asString(row['odometro'], fallback: '0')} km',
      horometerLabel: horometer,
      deviceId: device,
      imageName: asString(row['gif']),
      latitude: asDouble(row['latitud']),
      longitude: asDouble(row['longitud']),
    );
  }
}

class VehicleRef {
  const VehicleRef({
    required this.idMovil,
    required this.plate,
    required this.deviceId,
    required this.kms,
  });

  final int idMovil;
  final String plate;
  final int deviceId;
  final double kms;

  factory VehicleRef.fromBackend(Map<String, dynamic> row) {
    return VehicleRef(
      idMovil: asInt(row['idmovil']),
      plate: asString(row['placa']),
      deviceId: asInt(row['dip']),
      kms: asDouble(row['kms']),
    );
  }
}

class PendingAlarm {
  const PendingAlarm({
    required this.eventId,
    required this.plate,
    required this.event,
    required this.receivedAt,
    required this.position,
  });

  final int eventId;
  final String plate;
  final String event;
  final String receivedAt;
  final String position;

  factory PendingAlarm.fromBackend(Map<String, dynamic> row) {
    return PendingAlarm(
      eventId: asInt(row['id_eventoa'] ?? row['id_evento']),
      plate: asString(row['placaa'] ?? row['placa']),
      event: asString(row['eventoa'] ?? row['evento']),
      receivedAt: asString(row['fecha_llegadaa'] ?? row['fecha_llegada']),
      position: asString(row['posiciona'] ?? row['posicion']),
    );
  }
}

class AlarmHistoryItem {
  const AlarmHistoryItem({
    required this.event,
    required this.gpsDate,
    required this.position,
    required this.ignition,
    required this.speed,
  });

  final String event;
  final String gpsDate;
  final String position;
  final String ignition;
  final String speed;

  factory AlarmHistoryItem.fromBackend(Map<String, dynamic> row) {
    return AlarmHistoryItem(
      event: asString(row['evento']),
      gpsDate: asString(row['fecha_gps']),
      position: asString(row['posicion']),
      ignition: asString(row['ignicion']),
      speed: asString(row['velocidad']),
    );
  }
}

class CommandReply {
  const CommandReply({
    required this.response,
    required this.date,
    required this.plate,
  });

  final String response;
  final String date;
  final String plate;

  factory CommandReply.fromBackend(Map<String, dynamic> row) {
    return CommandReply(
      response: asString(row['respuesta']),
      date: asString(row['fecha']),
      plate: asString(row['placa']),
    );
  }
}

class ActionResult {
  const ActionResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  String toBackendPair() {
    // Backend expects [lon,lat] order in ST_GeomFromGeoJSON payload.
    return '[${_formatNumber(longitude)},${_formatNumber(latitude)}]';
  }
}

class GeofenceZone {
  const GeofenceZone({
    required this.id,
    required this.name,
    required this.associatedVehicles,
    required this.geometryType,
    required this.polygon,
  });

  final int id;
  final String name;
  final int associatedVehicles;
  final int geometryType;
  final List<GeoPoint> polygon;

  bool get hasPolygon => polygon.length >= 3;

  factory GeofenceZone.fromBackend(Map<String, dynamic> row) {
    final String geoJsonRaw = asString(row['the_geom']);
    return GeofenceZone(
      id: asInt(row['id_geo']),
      name: asString(row['nombre']),
      associatedVehicles: asInt(row['placa']),
      geometryType: asInt(row['tipo_geometria']),
      polygon: _extractPolygonFromGeoJson(geoJsonRaw),
    );
  }
}

class MediaEvidence {
  const MediaEvidence({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.position,
    required this.path,
    required this.latitude,
    required this.longitude,
    required this.duration,
    required this.name,
    required this.type,
  });

  final int id;
  final String startDate;
  final String endDate;
  final String position;
  final String path;
  final double latitude;
  final double longitude;
  final int duration;
  final String name;
  final int type;

  bool get isVideo => type == 2;
  bool get isImage => type == 1;

  String buildAbsoluteUrl({required String mediaBaseUrl}) {
    final String normalized = path
        .replaceAll('./../../', '')
        .replaceAll('../', '')
        .replaceAll('./', '')
        .replaceAll(RegExp(r'^/+'), '');
    final String base = mediaBaseUrl.endsWith('/') ? mediaBaseUrl : '$mediaBaseUrl/';
    return '$base$normalized';
  }

  factory MediaEvidence.fromBackend(Map<String, dynamic> row) {
    return MediaEvidence(
      id: asInt(row['id_video']),
      startDate: asString(row['fecha_inicio']),
      endDate: asString(row['fecha_fin']),
      position: asString(row['posicion']),
      path: asString(row['ruta_video']),
      latitude: asDouble(row['latitud']),
      longitude: asDouble(row['longitud']),
      duration: asInt(row['duracion']),
      name: asString(row['nombre']),
      type: asInt(row['tipo']),
    );
  }
}

String asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final String str = value.toString();
  return str.trim().isEmpty ? fallback : str;
}

int asInt(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? 0;
}

double asDouble(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

List<GeoPoint> _extractPolygonFromGeoJson(String geoJsonRaw) {
  if (geoJsonRaw.trim().isEmpty) {
    return const <GeoPoint>[];
  }

  try {
    final dynamic decoded = jsonDecode(geoJsonRaw);
    if (decoded is! Map<String, dynamic>) {
      return const <GeoPoint>[];
    }
    final String type = asString(decoded['type']).toLowerCase();
    final dynamic coords = decoded['coordinates'];

    if (type == 'polygon' && coords is List && coords.isNotEmpty) {
      return _pointsFromRing(coords.first);
    }

    if (type == 'multipolygon' && coords is List && coords.isNotEmpty) {
      final dynamic firstPolygon = coords.first;
      if (firstPolygon is List && firstPolygon.isNotEmpty) {
        return _pointsFromRing(firstPolygon.first);
      }
    }
  } catch (_) {
    return const <GeoPoint>[];
  }

  return const <GeoPoint>[];
}

List<GeoPoint> _pointsFromRing(dynamic ring) {
  if (ring is! List) {
    return const <GeoPoint>[];
  }

  final List<GeoPoint> points = <GeoPoint>[];
  for (final dynamic pair in ring) {
    if (pair is List && pair.length >= 2) {
      final double lon = asDouble(pair[0]);
      final double lat = asDouble(pair[1]);
      points.add(GeoPoint(latitude: lat, longitude: lon));
    }
  }

  // Remove duplicate closing point in UI representation.
  if (points.length > 1) {
    final GeoPoint first = points.first;
    final GeoPoint last = points.last;
    if ((first.latitude - last.latitude).abs() < 0.000001 &&
        (first.longitude - last.longitude).abs() < 0.000001) {
      points.removeLast();
    }
  }

  return points;
}

String _formatNumber(double value) {
  return value.toStringAsFixed(6);
}
