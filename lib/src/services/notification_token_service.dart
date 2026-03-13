import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTokenService {
  NotificationTokenService({
    this.firebaseReady = true,
    this.bootstrapError,
  });

  final bool firebaseReady;
  final String? bootstrapError;

  TokenResult emptyTokenResult() {
    return TokenResult.empty(platform: _platformName());
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
      ),
    );
  }

  Future<TokenResult> resolveToken() async {
    if (!firebaseReady) {
      return emptyTokenResult();
    }

    late final FirebaseMessaging messaging;

    try {
      messaging = FirebaseMessaging.instance;
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return emptyTokenResult();
      }
    } catch (_) {
      return emptyTokenResult();
    }

    String? apnsToken;
    String? fcmToken;
    for (int i = 0; i < 20; i++) {
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
        );
      }

      if ((apnsToken ?? '').isNotEmpty && i >= 2) {
        return TokenResult(
          token: apnsToken!,
          provider: 'apns',
          platform: _platformName(),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    return emptyTokenResult();
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
  });

  final String token;
  final String provider;
  final String platform;

  factory TokenResult.empty({required String platform}) {
    return TokenResult(token: 'vacio', provider: 'none', platform: platform);
  }
}
