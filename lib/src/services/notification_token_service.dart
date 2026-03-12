import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTokenService {
  Stream<TokenResult> tokenRefreshStream() {
    return FirebaseMessaging.instance.onTokenRefresh.map(
      (String token) => TokenResult(
        token: token.trim().isEmpty ? 'vacio' : token.trim(),
        provider: 'fcm',
        platform: _platformName(),
      ),
    );
  }

  Future<TokenResult> resolveToken() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return TokenResult.empty(platform: _platformName());
      }

      String? apnsToken;
      String? fcmToken;
      for (int i = 0; i < 15; i++) {
        apnsToken ??= await messaging.getAPNSToken();
        fcmToken ??= await messaging.getToken();

        if ((apnsToken ?? '').isNotEmpty || (fcmToken ?? '').isNotEmpty) {
          break;
        }

        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      if (apnsToken != null && apnsToken.isNotEmpty) {
        return TokenResult(
          token: apnsToken,
          provider: 'apns',
          platform: _platformName(),
        );
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        return TokenResult(
          token: fcmToken,
          provider: 'fcm',
          platform: _platformName(),
        );
      }

      return TokenResult.empty(platform: _platformName());
    } catch (_) {
      return TokenResult.empty(platform: _platformName());
    }
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
