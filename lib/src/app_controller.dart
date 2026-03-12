import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/domain_models.dart';
import 'services/backend_client.dart';
import 'services/notification_token_service.dart';
import 'services/session_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required BackendClient backendClient,
    required SessionStore sessionStore,
    required NotificationTokenService notificationService,
  })  : _backendClient = backendClient,
        _sessionStore = sessionStore,
        _notificationService = notificationService;

  final BackendClient _backendClient;
  final SessionStore _sessionStore;
  final NotificationTokenService _notificationService;
  StreamSubscription<TokenResult>? _tokenRefreshSubscription;

  bool bootstrapping = true;
  bool loggingIn = false;
  bool loadingDashboard = false;

  UserSession? session;
  MobileModuleAccess? moduleAccess;
  int vehiclesCount = 0;
  List<VehiclePosition> positions = const <VehiclePosition>[];
  String? errorMessage;

  bool get isAuthenticated => session != null;

  Future<void> bootstrap() async {
    _ensureTokenRefreshListener();
    bootstrapping = true;
    errorMessage = null;
    notifyListeners();

    final UserSession? savedSession = await _sessionStore.load();
    if (savedSession == null) {
      bootstrapping = false;
      notifyListeners();
      return;
    }

    session = savedSession;
    _backendClient.restoreSession(savedSession);

    try {
      await refreshDashboard(silent: true);
      try {
        await loadModuleAccess(silent: true);
      } catch (_) {
        // Keep dashboard available even if module permissions cannot be loaded.
      }
      unawaited(_syncNotificationToken());
    } catch (_) {
      await _clearLocalSession();
    }

    bootstrapping = false;
    notifyListeners();
  }

  Future<LoginResult> login({
    required String username,
    required String password,
    required int userType,
  }) async {
    _ensureTokenRefreshListener();
    loggingIn = true;
    errorMessage = null;
    notifyListeners();

    try {
      final TokenResult tokenResult = await _notificationService.resolveToken();
      final LoginResult result = await _backendClient.login(
        username: username,
        password: password,
        userType: userType,
        tokenId: tokenResult.token,
        tokenProvider: tokenResult.provider,
        tokenPlatform: tokenResult.platform,
      );

      if (!result.success) {
        loggingIn = false;
        errorMessage = result.message;
        notifyListeners();
        return result;
      }

      final String cookie = _extractCurrentCookie();
      if (cookie.isEmpty) {
        loggingIn = false;
        errorMessage = 'No se recibio cookie de sesion.';
        notifyListeners();
        return const LoginResult(
          success: false,
          message: 'No se recibio cookie de sesion.',
        );
      }

      final UserSession newSession = UserSession(
        sessionCookie: cookie,
        userType: userType,
        username: username.trim(),
        tokenId: tokenResult.token,
        tokenProvider: tokenResult.provider,
        tokenPlatform: tokenResult.platform,
        createdAtIso: DateTime.now().toIso8601String(),
      );

      session = newSession;
      await _sessionStore.save(newSession);
      unawaited(_syncNotificationToken(initialToken: tokenResult));
      try {
        await refreshDashboard(silent: true);
        try {
          await loadModuleAccess(silent: true);
        } catch (_) {
          // Module visibility falls back to local defaults when API is unavailable.
        }
      } on BackendException {
        if (session == null) {
          loggingIn = false;
          notifyListeners();
          return const LoginResult(
            success: false,
            message: 'La sesion expiro durante la carga inicial.',
          );
        }
      }

      loggingIn = false;
      notifyListeners();
      return const LoginResult(success: true, message: '');
    } on BackendException catch (ex) {
      loggingIn = false;
      errorMessage = ex.message;
      notifyListeners();
      return LoginResult(success: false, message: ex.message);
    } catch (_) {
      loggingIn = false;
      errorMessage = 'No fue posible iniciar sesion.';
      notifyListeners();
      return const LoginResult(success: false, message: 'No fue posible iniciar sesion.');
    }
  }

  Future<void> refreshDashboard({bool silent = false}) async {
    if (session == null) {
      return;
    }

    if (!silent) {
      loadingDashboard = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final int count = await _backendClient.fetchVehicleCount();
      final List<VehiclePosition> freshPositions = await _backendClient.fetchPositions();
      vehiclesCount = count;
      positions = freshPositions;
      if (moduleAccess == null) {
        try {
          moduleAccess = await _backendClient.fetchModuleAccess();
        } catch (_) {
          // Keep fallback visibility when module API cannot be reached.
        }
      }
      errorMessage = null;
    } on BackendException catch (ex) {
      errorMessage = ex.message;
      if (ex.message.toLowerCase().contains('sesion')) {
        await _clearLocalSession();
      }
      rethrow;
    } finally {
      loadingDashboard = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _backendClient.logout();
    await _clearLocalSession();
    notifyListeners();
  }

  bool isModuleEnabled(String moduleKey, {bool fallback = false}) {
    final MobileModuleAccess? access = moduleAccess;
    if (access != null) {
      return access.isEnabled(moduleKey, fallback: fallback);
    }
    return _defaultModuleFallback(moduleKey, fallback: fallback);
  }

  bool get canManageModules => moduleAccess?.canManageModules ?? false;

  Future<MobileModuleAccess?> loadModuleAccess({
    int? targetClientId,
    bool silent = false,
  }) async {
    try {
      final MobileModuleAccess access =
          await _backendClient.fetchModuleAccess(targetClientId: targetClientId);
      moduleAccess = access;
      if (!silent) {
        notifyListeners();
      }
      return access;
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      if (!silent) {
        errorMessage = ex.message;
        notifyListeners();
      }
      return null;
    }
  }

  Future<ActionResult> updateModuleAccess({
    required String module,
    required bool enabled,
    int? targetClientId,
  }) async {
    try {
      final MobileModuleAccess access = await _backendClient.setModuleAccess(
        module: module,
        enabled: enabled,
        targetClientId: targetClientId,
      );
      moduleAccess = access;
      notifyListeners();
      return const ActionResult(ok: true, message: 'Modulo actualizado.');
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      return ActionResult(ok: false, message: ex.message);
    }
  }

  Future<List<VehicleRef>> loadVehicles() async {
    try {
      return await _backendClient.fetchVehicles();
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<TravelHistoryItem>> loadTravelHistory({
    required int idMovil,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      return await _backendClient.fetchTravelHistory(
        idMovil: idMovil,
        from: from,
        to: to,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<PendingAlarm>> loadPendingAlarms() async {
    try {
      return await _backendClient.fetchPendingAlarms();
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<AlarmHistoryItem>> loadAlarmHistory({
    required int idMovil,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      return await _backendClient.fetchAlarmHistory(
        idMovil: idMovil,
        from: from,
        to: to,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<ActionResult> markAlarmAsAttended({
    required int eventId,
    required String note,
    required bool similar,
  }) async {
    try {
      return await _backendClient.attendAlarm(
        eventId: eventId,
        note: note,
        similar: similar,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<ActionResult> sendRemoteCommand({
    required int idMovil,
    required int commandType,
  }) async {
    try {
      return await _backendClient.sendCommand(
        idMovil: idMovil,
        commandType: commandType,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<ActionResult> sendVideoCommand({
    required int idMovil,
    required String command,
  }) async {
    try {
      return await _backendClient.sendCustomCommand(
        idMovil: idMovil,
        command: command,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<CommandReply?> getCommandReply({
    required int idMovil,
    required DateTime sentAfter,
  }) async {
    try {
      return await _backendClient.fetchCommandReply(
        idMovil: idMovil,
        sentAfter: sentAfter,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<GeofenceZone>> loadGeofences() async {
    try {
      return await _backendClient.fetchGeofences();
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<ActionResult> createGeofence({
    required String name,
    required List<GeoPoint> polygon,
  }) async {
    try {
      return await _backendClient.createGeofence(
        name: name,
        polygon: polygon,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<ActionResult> associateGeofence({
    required int idMovil,
    required int idGeofence,
    required bool useSchedule,
    required String startTime,
    required String endTime,
  }) async {
    try {
      return await _backendClient.associateGeofence(
        idMovil: idMovil,
        idGeofence: idGeofence,
        useSchedule: useSchedule,
        startTime: startTime,
        endTime: endTime,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<MediaEvidence>> loadMediaEvidence({
    required int idMovil,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      return await _backendClient.fetchMediaEvidence(
        idMovil: idMovil,
        from: from,
        to: to,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<ChecklistVehicle>> loadChecklistVehicles() async {
    try {
      return await _backendClient.fetchChecklistVehicles();
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<ChecklistItemDefinition>> loadChecklistItems() async {
    try {
      return await _backendClient.fetchChecklistItems();
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<List<ChecklistHistoryEntry>> loadChecklistHistory({int limit = 80}) async {
    try {
      return await _backendClient.fetchChecklistHistory(limit: limit);
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<ActionResult> saveChecklist({
    required int idMovil,
    required Map<String, dynamic> checks,
  }) async {
    try {
      return await _backendClient.saveChecklist(
        idMovil: idMovil,
        checks: checks,
      );
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  Future<ActionResult> triggerPanic({
    required String plate,
  }) async {
    try {
      return await _backendClient.triggerPanic(plate: plate);
    } on BackendException catch (ex) {
      await _handleBackendFailure(ex);
      rethrow;
    }
  }

  String _extractCurrentCookie() {
    return _backendClient.sessionCookie;
  }

  void _ensureTokenRefreshListener() {
    if (_tokenRefreshSubscription != null) {
      return;
    }

    _tokenRefreshSubscription = _notificationService.tokenRefreshStream().listen(
      (TokenResult tokenResult) {
        unawaited(_syncNotificationToken(initialToken: tokenResult));
      },
      onError: (_) {
        // Ignore stream errors; periodic sync still runs on login/bootstrap.
      },
    );
  }

  Future<void> _syncNotificationToken({TokenResult? initialToken}) async {
    if (session == null) {
      return;
    }

    TokenResult? tokenResult = initialToken;
    for (int attempt = 0; attempt < 12; attempt++) {
      if (attempt > 0) {
        final int waitSeconds = attempt > 6 ? 6 : attempt;
        await Future<void>.delayed(Duration(seconds: waitSeconds));
      }

      if (tokenResult == null ||
          tokenResult.token.trim().isEmpty ||
          tokenResult.token == 'vacio') {
        tokenResult = await _notificationService.resolveToken();
      }

      final String token = tokenResult.token.trim();
      if (token.isEmpty || token == 'vacio') {
        continue;
      }

      try {
        final ActionResult result = await _backendClient.registerNotificationToken(
          tokenId: token,
          tokenProvider: tokenResult.provider,
          tokenPlatform: tokenResult.platform,
        );
        if (!result.ok) {
          continue;
        }

        final UserSession? current = session;
        if (current == null) {
          return;
        }
        if (current.tokenId == token &&
            current.tokenProvider == tokenResult.provider &&
            current.tokenPlatform == tokenResult.platform) {
          return;
        }

        final UserSession updatedSession = UserSession(
          sessionCookie: current.sessionCookie,
          userType: current.userType,
          username: current.username,
          tokenId: token,
          tokenProvider: tokenResult.provider,
          tokenPlatform: tokenResult.platform,
          createdAtIso: current.createdAtIso,
        );
        session = updatedSession;
        await _sessionStore.save(updatedSession);
        notifyListeners();
      } catch (_) {
        // Ignore sync errors; login and dashboard remain usable.
      }

      return;
    }
  }

  Future<void> _clearLocalSession() async {
    session = null;
    moduleAccess = null;
    vehiclesCount = 0;
    positions = const <VehiclePosition>[];
    errorMessage = null;
    _backendClient.clearSession();
    await _sessionStore.clear();
  }

  @override
  void dispose() {
    final StreamSubscription<TokenResult>? subscription = _tokenRefreshSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _tokenRefreshSubscription = null;
    _backendClient.dispose();
    super.dispose();
  }

  Future<void> _handleBackendFailure(BackendException exception) async {
    if (exception.message.toLowerCase().contains('sesion')) {
      await _clearLocalSession();
      notifyListeners();
    }
  }

  bool _defaultModuleFallback(String moduleKey, {bool fallback = false}) {
    switch (moduleKey) {
      case 'map':
      case 'alarms':
      case 'reports':
      case 'checklist':
        return true;
      case 'commands':
        return false;
      case 'geofences':
        return true;
      default:
        return fallback;
    }
  }
}
