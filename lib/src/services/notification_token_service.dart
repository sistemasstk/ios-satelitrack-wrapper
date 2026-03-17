import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

class NotificationTokenService {
  NotificationTokenService({
    this.firebaseReady = true,
    this.bootstrapError,
  });

  static const MethodChannel _nativePushDebugChannel = MethodChannel(
    'satelitrack/push_debug',
  );

  final bool firebaseReady;
  final String? bootstrapError;

  TokenResult emptyTokenResult({String? diagnostic, String? permissionStatus, int apnsLength = 0}) {
    return TokenResult.empty(
      platform: _platformName(),
      diagnostic: diagnostic,
      permissionStatus: permissionStatus,
      apnsLength: apnsLength,
    );
  }

  String? get diagnosticMessage {
    if (firebaseReady) {
      return null;
    }

    final String raw = (bootstrapError ?? '').toLowerCase();
    if (raw.contains('google-service-info') || raw.contains('configuration file')) {
      return 'Notificaciones iOS no disponibles: falta la configuracion de Firebase en la compilacion.';
    }
    if (raw.contains('apns') || raw.contains('push')) {
      return 'Notificaciones iOS no disponibles: revisa capacidades Push/APNs en la compilacion.';
    }
    return 'Notificaciones iOS no disponibles en esta compilacion.';
  }

  Stream<TokenResult> tokenRefreshStream() {
    if (!firebaseReady) {
      return const Stream<TokenResult>.empty();
    }
    return FirebaseMessaging.instance.onTokenRefresh.map(
      (String token) => TokenResult(
        token: token.trim().isEmpty ? 'vacio' : token.trim(),
        provider: 'fcm',
        platform: _platformName(),
        diagnostic: 'Token actualizado desde Firebase onTokenRefresh.',
      ),
    );
  }

  Future<TokenResult> resolveToken() async {
    if (!firebaseReady) {
      return emptyTokenResult(
        diagnostic: diagnosticMessage ?? 'Firebase no esta listo en esta compilacion.',
      );
    }

    late final FirebaseMessaging messaging;
    String permissionStatus = 'unknown';
    messaging = FirebaseMessaging.instance;

    if (Platform.isIOS) {
      await _requestNativeRegistration();
    } else {
      try {
        final NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        permissionStatus = settings.authorizationStatus.name;

        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          return emptyTokenResult(
            diagnostic: 'El usuario rechazo el permiso de notificaciones.',
            permissionStatus: permissionStatus,
          );
        }
      } catch (ex) {
        return emptyTokenResult(
          diagnostic: 'Fallo solicitando permisos o inicializando Firebase Messaging: $ex',
          permissionStatus: permissionStatus,
        );
      }
    }

    String? apnsToken;
    String? fcmToken;
    NativePushDebugState nativeState = const NativePushDebugState();
    for (int i = 0; i < 30; i++) {
      nativeState = await _loadNativePushDebugState();
      if (nativeState.authorizationStatus.isNotEmpty) {
        permissionStatus = nativeState.authorizationStatus;
      }
      if (nativeState.apnsToken.isNotEmpty) {
        apnsToken = nativeState.apnsToken;
      }
      if (nativeState.fcmToken.isNotEmpty) {
        fcmToken = nativeState.fcmToken;
      }

      try {
        final String? candidateApns = await messaging.getAPNSToken();
        if ((candidateApns ?? '').trim().isNotEmpty) {
          apnsToken = candidateApns!.trim();
        }
      } catch (_) {
        // Keep polling; APNs token may not be available immediately on iOS.
      }

      final bool canRequestFcm = !Platform.isIOS || (apnsToken ?? '').isNotEmpty;
      if (canRequestFcm) {
        try {
          final String? candidateFcm = await messaging.getToken();
          if ((candidateFcm ?? '').trim().isNotEmpty) {
            fcmToken = candidateFcm!.trim();
          }
        } catch (_) {
          // Firebase can throw before APNs registration is fully ready.
        }
      }

      if ((fcmToken ?? '').isNotEmpty) {
        return TokenResult(
          token: fcmToken!,
          provider: 'fcm',
          platform: _platformName(),
          diagnostic: 'Token FCM obtenido correctamente.',
          permissionStatus: permissionStatus,
          apnsLength: (apnsToken ?? '').length,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if ((apnsToken ?? '').isEmpty) {
      return emptyTokenResult(
        diagnostic:
            _buildApnsMissingDiagnostic(nativeState),
        permissionStatus: permissionStatus,
        apnsLength: 0,
      );
    }

    return emptyTokenResult(
      diagnostic:
          _buildFcmMissingDiagnostic(nativeState),
      permissionStatus: permissionStatus,
      apnsLength: (apnsToken ?? '').length,
    );
  }

  Future<void> _requestNativeRegistration() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _nativePushDebugChannel.invokeMethod<Map<dynamic, dynamic>>('register');
    } catch (_) {
      // The app still has the Firebase path as fallback.
    }
  }

  Future<NativePushDebugState> _loadNativePushDebugState() async {
    if (!Platform.isIOS) {
      return const NativePushDebugState();
    }
    try {
      final Map<dynamic, dynamic>? payload =
          await _nativePushDebugChannel.invokeMethod<Map<dynamic, dynamic>>('getState');
      return NativePushDebugState.fromMap(payload);
    } catch (_) {
      return const NativePushDebugState();
    }
  }

  String _buildApnsMissingDiagnostic(NativePushDebugState nativeState) {
    final List<String> parts = <String>[
      'No se obtuvo token APNs.',
    ];
    if (nativeState.lastEvent.isNotEmpty) {
      parts.add('lastEvent=${nativeState.lastEvent}.');
    }
    if (nativeState.authorizationStatus.isNotEmpty) {
      parts.add('authorizationStatus=${nativeState.authorizationStatus}.');
    }
    parts.add(
      nativeState.isRegisteredForRemoteNotifications
          ? 'iOS reporta registro remoto activo.'
          : 'iOS aun no reporta registro remoto activo.',
    );
    if (nativeState.apnsError.isNotEmpty) {
      parts.add('Error nativo APNs: ${nativeState.apnsError}.');
    } else {
      parts.add(
        'Aunque enviaremos por FCM, iOS igual necesita Push Notifications/APNs activos en Apple Developer y en el provisioning profile.',
      );
    }
    return parts.join(' ');
  }

  String _buildFcmMissingDiagnostic(NativePushDebugState nativeState) {
    final List<String> parts = <String>[
      'APNs ya respondio, pero Firebase no entrego el token FCM.',
    ];
    if (nativeState.lastEvent.isNotEmpty) {
      parts.add('lastEvent=${nativeState.lastEvent}.');
    }
    if (nativeState.authorizationStatus.isNotEmpty) {
      parts.add('authorizationStatus=${nativeState.authorizationStatus}.');
    }
    if (nativeState.apnsError.isNotEmpty) {
      parts.add('Error nativo APNs: ${nativeState.apnsError}.');
    }
    if (nativeState.fcmError.isNotEmpty) {
      parts.add('Error nativo FCM: ${nativeState.fcmError}.');
    }
    parts.add(
      'Revisa en Firebase > Cloud Messaging la APNs Auth Key (.p8), Team ID y Key ID, luego reinstala la app.',
    );
    return parts.join(' ');
  }

  String _platformName() {
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    return 'unknown';
  }
}

class NativePushDebugState {
  const NativePushDebugState({
    this.apnsToken = '',
    this.fcmToken = '',
    this.apnsError = '',
    this.fcmError = '',
    this.lastEvent = '',
    this.authorizationStatus = '',
    this.isRegisteredForRemoteNotifications = false,
  });

  final String apnsToken;
  final String fcmToken;
  final String apnsError;
  final String fcmError;
  final String lastEvent;
  final String authorizationStatus;
  final bool isRegisteredForRemoteNotifications;

  factory NativePushDebugState.fromMap(Map<dynamic, dynamic>? payload) {
    if (payload == null) {
      return const NativePushDebugState();
    }
    return NativePushDebugState(
      apnsToken: (payload['apnsToken'] ?? '').toString(),
      fcmToken: (payload['fcmToken'] ?? '').toString(),
      apnsError: (payload['apnsError'] ?? '').toString(),
      fcmError: (payload['fcmError'] ?? '').toString(),
      lastEvent: (payload['lastEvent'] ?? '').toString(),
      authorizationStatus: (payload['authorizationStatus'] ?? '').toString(),
      isRegisteredForRemoteNotifications:
          payload['isRegisteredForRemoteNotifications'] == true,
    );
  }
}

class TokenResult {
  const TokenResult({
    required this.token,
    required this.provider,
    required this.platform,
    this.diagnostic,
    this.permissionStatus,
    this.apnsLength = 0,
  });

  final String token;
  final String provider;
  final String platform;
  final String? diagnostic;
  final String? permissionStatus;
  final int apnsLength;

  factory TokenResult.empty({
    required String platform,
    String? diagnostic,
    String? permissionStatus,
    int apnsLength = 0,
  }) {
    return TokenResult(
      token: 'vacio',
      provider: 'none',
      platform: platform,
      diagnostic: diagnostic,
      permissionStatus: permissionStatus,
      apnsLength: apnsLength,
    );
  }
}
