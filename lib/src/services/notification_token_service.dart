import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTokenService {
  NotificationTokenService({
    this.firebaseReady = true,
    this.bootstrapError,
  });

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

    try {
      messaging = FirebaseMessaging.instance;
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

    String? apnsToken;
    String? fcmToken;
    for (int i = 0; i < 30; i++) {
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
            'No se obtuvo token APNs. Aunque enviaremos por FCM, iOS igual necesita Push Notifications/APNs activos en Apple Developer y en el provisioning profile.',
        permissionStatus: permissionStatus,
        apnsLength: 0,
      );
    }

    return emptyTokenResult(
      diagnostic:
          'APNs ya respondio, pero Firebase no entrego el token FCM. Revisa en Firebase > Cloud Messaging la APNs Auth Key (.p8), Team ID y Key ID, luego reinstala la app.',
      permissionStatus: permissionStatus,
      apnsLength: (apnsToken ?? '').length,
    );
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
