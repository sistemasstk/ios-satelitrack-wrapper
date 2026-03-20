import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/domain_models.dart';

class BackendClient {
  BackendClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _sessionCookie;

  void restoreSession(UserSession? session) {
    _sessionCookie = session?.sessionCookie;
  }

  bool get hasSession => (_sessionCookie ?? '').isNotEmpty;
  String get sessionCookie => _sessionCookie ?? '';

  Future<LoginResult> login({
    required String username,
    required String password,
    required int userType,
    required String tokenId,
    required String tokenProvider,
    required String tokenPlatform,
  }) async {
    final http.Request request = http.Request('POST', AppConfig.resolve('login.php'))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
      ..bodyFields = <String, String>{
        'username': username,
        'password': password,
        'tipo_usuario': userType.toString(),
        'token_id': tokenId,
        'version': AppConfig.appVersion,
        'token_provider': tokenProvider,
        'token_platform': tokenPlatform,
      };

    if (hasSession) {
      request.headers['Cookie'] = _sessionCookie!;
    }

    final http.StreamedResponse response;
    final String body;
    try {
      response = await _httpClient.send(request);
      body = await response.stream.bytesToString();
    } catch (ex) {
      throw BackendException(_networkExceptionMessage(ex));
    }
    final String location = (response.headers['location'] ?? '').toLowerCase();
    final String? newSessionCookie = _extractPhpSessionCookie(response.headers['set-cookie']);

    final bool success = location.contains('dasboard.php') ||
        (response.statusCode == 200 && body.toLowerCase().contains('dashboard'));

    if (success) {
      if (newSessionCookie != null && newSessionCookie.isNotEmpty) {
        _sessionCookie = newSessionCookie;
      }
      if (!hasSession) {
        return const LoginResult(
          success: false,
          message: 'No se pudo establecer sesion con el backend.',
        );
      }
      // Best-effort token sync right after login to avoid losing iOS token registration.
      if (tokenId.trim().isNotEmpty && tokenId.trim() != 'vacio') {
        try {
          await _postFunctionMap(
            idfn: 18,
            payload: <String, dynamic>{
              'token_id': tokenId.trim(),
              'version': _appVersionNumber(),
              'token_provider': tokenProvider,
              'token_platform': tokenPlatform,
            },
          );
        } catch (_) {
          // Ignore here; AppController retries token sync in background.
        }
      }
      return const LoginResult(success: true, message: '');
    }

    if (location.contains('error=1')) {
      return const LoginResult(success: false, message: 'Usuario o clave invalidos.');
    }

    return LoginResult(
      success: false,
      message: 'No fue posible iniciar sesion (HTTP ${response.statusCode}).',
    );
  }

  Future<int> fetchVehicleCount() async {
    final List<dynamic> list = await _postFunctionList(idfn: 1);
    if (list.isEmpty) {
      return 0;
    }
    final Map<String, dynamic> row = _decodeRow(list.first);
    return asInt(row['count']);
  }

  Future<List<VehiclePosition>> fetchPositions() async {
    final List<dynamic> list = await _postFunctionList(idfn: 2);
    final List<VehiclePosition> positions = <VehiclePosition>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> row = _decodeRow(item);
      if (row.isEmpty) {
        continue;
      }
      positions.add(VehiclePosition.fromBackend(row));
    }
    return positions;
  }

  Future<List<VehicleRef>> fetchVehicles() async {
    final List<dynamic> list = await _postFunctionList(idfn: 3);
    final List<VehicleRef> vehicles = <VehicleRef>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> row = _decodeRow(item);
      if (row.isEmpty) {
        continue;
      }
      vehicles.add(VehicleRef.fromBackend(row));
    }
    vehicles.sort((VehicleRef a, VehicleRef b) => a.plate.compareTo(b.plate));
    return vehicles;
  }

  Future<List<TravelHistoryItem>> fetchTravelHistory({
    required int idMovil,
    required DateTime from,
    required DateTime to,
  }) async {
    final List<dynamic> list = await _postFunctionList(
      idfn: 4,
      payload: <String, dynamic>{
        'limitevel': 0,
        'idmovil': idMovil,
        'finicio': _formatDateTime(from),
        'ffin': _formatDateTime(to),
      },
    );

    final List<TravelHistoryItem> history = <TravelHistoryItem>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> row = _decodeRow(item);
      if (row.isEmpty) {
        continue;
      }
      history.add(TravelHistoryItem.fromBackend(row));
    }
    history.sort((TravelHistoryItem a, TravelHistoryItem b) => a.gpsDate.compareTo(b.gpsDate));
    return history;
  }

  Future<List<PendingAlarm>> fetchPendingAlarms() async {
    final List<dynamic> list = await _postFunctionList(idfn: 6);
    final List<PendingAlarm> alarms = <PendingAlarm>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> row = _decodeRow(item);
      if (row.isEmpty) {
        continue;
      }
      alarms.add(PendingAlarm.fromBackend(row));
    }
    return alarms;
  }

  Future<List<AlarmHistoryItem>> fetchAlarmHistory({
    required int idMovil,
    required DateTime from,
    required DateTime to,
  }) async {
    final List<dynamic> list = await _postFunctionList(
      idfn: 5,
      payload: <String, dynamic>{
        'limitevel': 0,
        'idmovil': idMovil,
        'finicio': _formatDateTime(from),
        'ffin': _formatDateTime(to),
      },
    );

    final List<AlarmHistoryItem> events = <AlarmHistoryItem>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> row = _decodeRow(item);
      if (row.isEmpty) {
        continue;
      }
      events.add(AlarmHistoryItem.fromBackend(row));
    }
    return events;
  }

  Future<ActionResult> attendAlarm({
    required int eventId,
    required String note,
    required bool similar,
  }) async {
    final Map<String, dynamic> result = await _postFunctionMap(
      idfn: 7,
      payload: <String, dynamic>{
        'idev': eventId,
        'nov': note,
        'sim': similar ? 1 : 0,
      },
    );

    return ActionResult(
      ok: asString(result['cod']) == '1000',
      message: asString(result['mensaje'], fallback: 'Respuesta sin mensaje.'),
    );
  }

  Future<ActionResult> sendCommand({
    required int idMovil,
    required int commandType,
  }) async {
    final Map<String, dynamic> result = await _postFunctionMap(
      idfn: 8,
      payload: <String, dynamic>{
        'id_cmd': commandType,
        'idmovil': idMovil,
      },
    );

    return ActionResult(
      ok: asString(result['cod1']) == '1000',
      message: asString(result['mensaje1'], fallback: 'Respuesta sin mensaje.'),
    );
  }

  Future<ActionResult> sendCustomCommand({
    required int idMovil,
    required String command,
  }) async {
    final Map<String, dynamic> result = await _postFunctionMap(
      idfn: 14,
      payload: <String, dynamic>{
        'id_cmd': 0,
        'idmovil': idMovil,
        'comando': command,
      },
    );

    return ActionResult(
      ok: asString(result['cod1']) == '1000',
      message: asString(result['mensaje1'], fallback: 'Respuesta sin mensaje.'),
    );
  }

  Future<CommandReply?> fetchCommandReply({
    required int idMovil,
    required DateTime sentAfter,
  }) async {
    final List<dynamic> list = await _postFunctionList(
      idfn: 12,
      payload: <String, dynamic>{
        'idmovil': idMovil,
        'f_envio': _formatDateTime(sentAfter),
      },
    );

    if (list.isEmpty) {
      return null;
    }
    final Map<String, dynamic> row = _decodeRow(list.first);
    if (row.isEmpty) {
      return null;
    }
    return CommandReply.fromBackend(row);
  }

  Future<List<GeofenceZone>> fetchGeofences() async {
    final List<dynamic> list = await _postFunctionList(idfn: 10);
    final List<GeofenceZone> items = <GeofenceZone>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> row = _decodeRow(item);
      if (row.isEmpty) {
        continue;
      }
      items.add(GeofenceZone.fromBackend(row));
    }
    items.sort((GeofenceZone a, GeofenceZone b) => a.name.compareTo(b.name));
    return items;
  }

  Future<ActionResult> createGeofence({
    required String name,
    required List<GeoPoint> polygon,
  }) async {
    if (polygon.length < 3) {
      return const ActionResult(ok: false, message: 'Debes definir al menos 3 puntos.');
    }

    final String coords = _toBackendPolygon(polygon);
    final Map<String, dynamic> result = await _postFunctionMap(
      idfn: 9,
      payload: <String, dynamic>{
        'tipo': 'Polygon',
        'coords': coords,
        'nomgeo': name,
      },
    );

    return ActionResult(
      ok: asString(result['cod1']) == '1000',
      message: asString(result['mensaje1'], fallback: 'Respuesta sin mensaje.'),
    );
  }

  Future<ActionResult> associateGeofence({
    required int idMovil,
    required int idGeofence,
    required bool useSchedule,
    required String startTime,
    required String endTime,
  }) async {
    final Map<String, dynamic> result = await _postFunctionMap(
      idfn: 11,
      payload: <String, dynamic>{
        'idmovil': idMovil,
        'idgeo': idGeofence,
        'horario': useSchedule ? 1 : 0,
        'horai': startTime,
        'horaf': endTime,
      },
    );

    return ActionResult(
      ok: asString(result['cod1']) == '1000',
      message: asString(
        result['mensaje'],
        fallback: asString(result['mensaje1'], fallback: 'Respuesta sin mensaje.'),
      ),
    );
  }

  Future<List<MediaEvidence>> fetchMediaEvidence({
    required int idMovil,
    required DateTime from,
    required DateTime to,
  }) async {
    final List<dynamic> list = await _postFunctionList(
      idfn: 15,
      payload: <String, dynamic>{
        'limitevel': 0,
        'idmovil': idMovil,
        'finicio': _formatDateTime(from),
        'ffin': _formatDateTime(to),
      },
    );

    final List<MediaEvidence> media = <MediaEvidence>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> row = _decodeRow(item);
      if (row.isEmpty) {
        continue;
      }
      media.add(MediaEvidence.fromBackend(row));
    }
    media.sort((MediaEvidence a, MediaEvidence b) => b.endDate.compareTo(a.endDate));
    return media;
  }

  Future<ActionResult> registerNotificationToken({
    required String tokenId,
    required String tokenProvider,
    required String tokenPlatform,
  }) async {
    final String normalizedToken = tokenId.trim().isEmpty ? 'vacio' : tokenId.trim();

    final Map<String, dynamic> result = await _postFunctionMap(
      idfn: 18,
      payload: <String, dynamic>{
        'token_id': normalizedToken,
        'version': _appVersionNumber(),
        'token_provider': tokenProvider,
        'token_platform': tokenPlatform,
      },
    );

    return ActionResult(
      ok: asString(result['cod1']) == '1000',
      message: asString(result['mensaje1'], fallback: 'Respuesta sin mensaje.'),
    );
  }

  Future<MobileModuleAccess> fetchModuleAccess({int? targetClientId}) async {
    final Map<String, dynamic> envelope = await _postJsonApiEnvelope(
      path: 'includes/mobile_app_admin_api.php',
      payload: <String, dynamic>{
        'action': 'get_modules',
        if (targetClientId != null) 'target_client_id': targetClientId,
      },
    );
    final dynamic data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const BackendException('Respuesta invalida de modulos.');
    }
    return MobileModuleAccess.fromBackend(data);
  }

  Future<MobileModuleAccess> setModuleAccess({
    required String module,
    required bool enabled,
    int? targetClientId,
  }) async {
    final Map<String, dynamic> envelope = await _postJsonApiEnvelope(
      path: 'includes/mobile_app_admin_api.php',
      payload: <String, dynamic>{
        'action': 'set_module',
        'module': module,
        'enabled': enabled,
        if (targetClientId != null) 'target_client_id': targetClientId,
      },
    );
    final dynamic data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const BackendException('Respuesta invalida al guardar modulo.');
    }
    return MobileModuleAccess.fromBackend(data);
  }

  Future<List<ChecklistVehicle>> fetchChecklistVehicles() async {
    final Map<String, dynamic> envelope = await _postJsonApiEnvelope(
      path: 'includes/checklist_preoperativo_api.php',
      payload: const <String, dynamic>{'action': 'obtener_vehiculos'},
    );
    final dynamic data = envelope['data'];
    if (data is! List<dynamic>) {
      return const <ChecklistVehicle>[];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChecklistVehicle.fromBackend)
        .toList(growable: false);
  }

  Future<List<ChecklistItemDefinition>> fetchChecklistItems() async {
    final Map<String, dynamic> envelope = await _postJsonApiEnvelope(
      path: 'includes/checklist_preoperativo_api.php',
      payload: const <String, dynamic>{'action': 'obtener_items'},
    );
    final dynamic data = envelope['data'];
    if (data is! List<dynamic>) {
      return const <ChecklistItemDefinition>[];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChecklistItemDefinition.fromBackend)
        .toList(growable: false);
  }

  Future<ActionResult> saveChecklist({
    required int idMovil,
    required Map<String, dynamic> checks,
  }) async {
    final Map<String, dynamic> envelope = await _postJsonApiEnvelope(
      path: 'includes/checklist_preoperativo_api.php',
      payload: <String, dynamic>{
        'action': 'guardar_checklist',
        'id_movil': idMovil,
        'checks': checks,
      },
    );
    return ActionResult(
      ok: true,
      message: asString(envelope['message'], fallback: 'Checklist guardado correctamente.'),
    );
  }

  Future<List<ChecklistHistoryEntry>> fetchChecklistHistory({int limit = 80}) async {
    final Map<String, dynamic> envelope = await _postJsonApiEnvelope(
      path: 'includes/checklist_preoperativo_api.php',
      payload: <String, dynamic>{
        'action': 'obtener_historial',
        'limit': limit,
      },
    );
    final dynamic data = envelope['data'];
    if (data is! List<dynamic>) {
      return const <ChecklistHistoryEntry>[];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChecklistHistoryEntry.fromBackend)
        .toList(growable: false);
  }

  Future<ActionResult> triggerPanic({
    required String plate,
  }) async {
    final Map<String, dynamic> result = await _postFunctionMap(
      idfn: 16,
      payload: <String, dynamic>{
        'placap': plate,
      },
    );

    return ActionResult(
      ok: asString(result['cod1']) == '1000',
      message: asString(result['mensaje1'], fallback: 'Respuesta sin mensaje.'),
    );
  }

  Future<void> logout() async {
    if (!hasSession) {
      return;
    }

    final http.Request request = http.Request('GET', AppConfig.resolve('logout.php'))
      ..followRedirects = false
      ..headers['Cookie'] = _sessionCookie!;

    try {
      await _httpClient.send(request);
    } catch (_) {
      // Ignore network errors on logout; local session cleanup still applies.
    } finally {
      _sessionCookie = null;
    }
  }

  void clearSession() {
    _sessionCookie = null;
  }

  void dispose() {
    _httpClient.close();
  }

  Future<List<dynamic>> _postFunctionList({
    required int idfn,
    Map<String, dynamic>? payload,
  }) async {
    final dynamic decoded = await _postFunctionRaw(idfn: idfn, payload: payload);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      return <dynamic>[decoded];
    }
    return const <dynamic>[];
  }

  Future<Map<String, dynamic>> _postFunctionMap({
    required int idfn,
    Map<String, dynamic>? payload,
  }) async {
    final dynamic decoded = await _postFunctionRaw(idfn: idfn, payload: payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const BackendException('Formato de respuesta inesperado.');
  }

  Future<dynamic> _postFunctionRaw({
    required int idfn,
    Map<String, dynamic>? payload,
    bool allowSessionRetry = true,
  }) async {
    if (!hasSession) {
      throw const BackendException('Sesion no disponible. Inicia sesion de nuevo.');
    }

    final Map<String, dynamic> body = <String, dynamic>{'idfn': idfn.toString(), ...?payload};

    final http.Response response;
    try {
      response = await _httpClient.post(
        AppConfig.resolve('includes/funciones.php'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Cookie': _sessionCookie!,
        },
        body: jsonEncode(body),
      );
    } catch (ex) {
      throw BackendException(_networkExceptionMessage(ex));
    }

    final String rawBody = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String backendError = _extractBackendError(rawBody);
      if (allowSessionRetry && _shouldRetryRecoverableSessionIssue(backendError, rawBody)) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return _postFunctionRaw(
          idfn: idfn,
          payload: payload,
          allowSessionRetry: false,
        );
      }
      if (backendError.isNotEmpty) {
        throw BackendException(backendError);
      }
      throw BackendException('Backend devolvio HTTP ${response.statusCode}.');
    }

    if (rawBody.isEmpty) {
      return const <dynamic>[];
    }
    if (rawBody.startsWith('<')) {
      if (allowSessionRetry) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return _postFunctionRaw(
          idfn: idfn,
          payload: payload,
          allowSessionRetry: false,
        );
      }
      throw const BackendException('Sesion expirada o respuesta invalida del backend.');
    }

    try {
      return jsonDecode(rawBody);
    } catch (_) {
      final String backendError = _extractBackendError(rawBody);
      if (allowSessionRetry && _shouldRetryRecoverableSessionIssue(backendError, rawBody)) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return _postFunctionRaw(
          idfn: idfn,
          payload: payload,
          allowSessionRetry: false,
        );
      }
      if (backendError.isNotEmpty) {
        throw BackendException(backendError);
      }
      throw BackendException('No se pudo decodificar respuesta JSON: $rawBody');
    }
  }

  Future<Map<String, dynamic>> _postJsonApiEnvelope({
    required String path,
    required Map<String, dynamic> payload,
    bool allowSessionRetry = true,
  }) async {
    if (!hasSession) {
      throw const BackendException('Sesion no disponible. Inicia sesion de nuevo.');
    }

    final http.Response response;
    try {
      response = await _httpClient.post(
        AppConfig.resolve(path),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Cookie': _sessionCookie!,
        },
        body: jsonEncode(payload),
      );
    } catch (ex) {
      throw BackendException(_networkExceptionMessage(ex));
    }

    final String rawBody = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String backendError = _extractBackendError(rawBody);
      if (allowSessionRetry && _shouldRetryRecoverableSessionIssue(backendError, rawBody)) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return _postJsonApiEnvelope(
          path: path,
          payload: payload,
          allowSessionRetry: false,
        );
      }
      if (backendError.isNotEmpty) {
        throw BackendException(backendError);
      }
      throw BackendException('Backend devolvio HTTP ${response.statusCode}.');
    }

    if (rawBody.isEmpty) {
      throw const BackendException('Respuesta vacia del backend.');
    }
    if (rawBody.startsWith('<')) {
      if (allowSessionRetry) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return _postJsonApiEnvelope(
          path: path,
          payload: payload,
          allowSessionRetry: false,
        );
      }
      throw const BackendException('Sesion expirada o respuesta invalida del backend.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(rawBody);
    } catch (_) {
      final String backendError = _extractBackendError(rawBody);
      if (allowSessionRetry && _shouldRetryRecoverableSessionIssue(backendError, rawBody)) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return _postJsonApiEnvelope(
          path: path,
          payload: payload,
          allowSessionRetry: false,
        );
      }
      if (backendError.isNotEmpty) {
        throw BackendException(backendError);
      }
      throw BackendException('No se pudo decodificar respuesta JSON: $rawBody');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackendException('Formato de respuesta inesperado.');
    }

    final bool success = asBool(decoded['success']);
    if (!success) {
      final String errorMessage = asString(
        decoded['error'],
        fallback: asString(decoded['message'], fallback: 'Operacion no exitosa.'),
      );
      throw BackendException(errorMessage);
    }

    return decoded;
  }

  Map<String, dynamic> _decodeRow(dynamic item) {
    if (item is! Map<String, dynamic>) {
      return const <String, dynamic>{};
    }

    final dynamic row = item['row_to_json'];
    if (row is Map<String, dynamic>) {
      return row;
    }

    if (row is String && row.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(row);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return const <String, dynamic>{};
      }
    }

    // For some endpoints the backend already returns a plain object.
    if (!item.containsKey('row_to_json')) {
      return item;
    }

    return const <String, dynamic>{};
  }

  String? _extractPhpSessionCookie(String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.isEmpty) {
      return null;
    }

    final RegExpMatch? match = RegExp(r'PHPSESSID=[^;, ]+').firstMatch(setCookieHeader);
    return match?.group(0);
  }
}

bool _shouldRetryRecoverableSessionIssue(String backendError, String rawBody) {
  final String source = (backendError.isNotEmpty ? backendError : rawBody).toLowerCase();
  return source.contains('sesion no esta disponible en este nodo') ||
      source.contains('sticky sessions') ||
      source.contains('almacenamiento compartido de sesiones') ||
      source.contains('sql incompleto') ||
      source.contains('sesion expirada') ||
      source.contains('respuesta invalida del backend') ||
      source.contains('no puedo,error');
}

String _extractBackendError(String rawBody) {
  final String trimmed = rawBody.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  try {
    final dynamic decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      final String message = asString(
        decoded['error'],
        fallback: asString(decoded['message'], fallback: asString(decoded['mensaje1'])),
      ).trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
  } catch (_) {
    // Fall back to plain-text heuristics.
  }

  final String lower = trimmed.toLowerCase();
  if (lower.contains('sesion invalida') ||
      lower.contains('sesion no disponible') ||
      lower.contains('sticky sessions') ||
      lower.contains('almacenamiento compartido de sesiones')) {
    return 'La sesion no esta disponible en este nodo del balanceador. Revisa sticky sessions o sesiones compartidas entre los servidores.';
  }
  if (lower.contains('no puedo,error select') ||
      lower.contains('where (id_cliente= or id_empresa=') ||
      lower.contains('where mt.id_cliente =')) {
    return 'El servidor respondio sin sesion activa y genero SQL incompleto. Revisa sticky sessions o almacenamiento compartido de sesiones entre Windows y Ubuntu.';
  }

  return '';
}

class LoginResult {
  const LoginResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _formatDateTime(DateTime value) {
  final String year = value.year.toString().padLeft(4, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  final String second = value.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}

String _networkExceptionMessage(Object error) {
  final String raw = error.toString().toLowerCase();
  if (raw.contains('timed out')) {
    return 'El servidor tardo demasiado en responder.';
  }
  if (raw.contains('certificate') || raw.contains('handshake')) {
    return 'No fue posible validar la conexion segura con el servidor.';
  }
  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection closed') ||
      raw.contains('connection refused') ||
      raw.contains('network is unreachable')) {
    return 'No fue posible conectar con el servidor.';
  }
  return 'Ocurrio un error de red al comunicar con el servidor.';
}

int _appVersionNumber() {
  return int.tryParse(AppConfig.appVersion) ?? 0;
}

String _toBackendPolygon(List<GeoPoint> points) {
  final List<GeoPoint> ring = <GeoPoint>[...points];
  if (ring.isNotEmpty) {
    final GeoPoint first = ring.first;
    final GeoPoint last = ring.last;
    final bool closed = (first.latitude - last.latitude).abs() < 0.000001 &&
        (first.longitude - last.longitude).abs() < 0.000001;
    if (!closed) {
      ring.add(first);
    }
  }

  final String inner = ring.map((GeoPoint p) => p.toBackendPair()).join(',');
  return '[[${inner}]]';
}
