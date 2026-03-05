import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  } catch (_) {
    // Keep startup alive even when Firebase is not configured yet.
  }

  runApp(const SatelitrackWrapperApp());
}

class SatelitrackWrapperApp extends StatelessWidget {
  const SatelitrackWrapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WrapperBootstrapPage(),
    );
  }
}

class WrapperBootstrapPage extends StatefulWidget {
  const WrapperBootstrapPage({super.key});

  @override
  State<WrapperBootstrapPage> createState() => _WrapperBootstrapPageState();
}

class _WrapperBootstrapPageState extends State<WrapperBootstrapPage> {
  static const String _defaultUrl = 'https://TU-DOMINIO.com/app2025/index.php';
  static const String _defaultVersion = '2025';

  late final WebViewController _controller;
  String _status = 'Preparando aplicación...';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (kDebugMode) {
              debugPrint('WebView error: ${error.description}');
            }
          },
        ),
      );

    unawaited(_bootstrap());
    _listenForNotificationOpen();
  }

  Future<void> _bootstrap() async {
    final tokenResult = await _resolveToken();
    final targetUrl = _buildAppUrl(
      token: tokenResult.token,
      provider: tokenResult.provider,
    );

    if (mounted) {
      setState(() {
        _status = 'Redirigiendo...';
        _loaded = true;
      });
    }

    await _controller.loadRequest(Uri.parse(targetUrl));
  }

  Future<TokenResult> _resolveToken() async {
    try {
      setState(() => _status = 'Solicitando permisos de notificación...');
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return const TokenResult(token: 'vacio', provider: 'none');
      }

      setState(() => _status = 'Obteniendo token APNs/FCM...');
      String? apnsToken;
      for (var i = 0; i < 10; i++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final fcmToken = await messaging.getToken();

      if (apnsToken != null && apnsToken.isNotEmpty) {
        return TokenResult(token: apnsToken, provider: 'apns');
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        return TokenResult(token: fcmToken, provider: 'fcm');
      }

      return const TokenResult(token: 'vacio', provider: 'none');
    } catch (_) {
      return const TokenResult(token: 'vacio', provider: 'none');
    }
  }

  String _buildAppUrl({required String token, required String provider}) {
    final baseUrl = const String.fromEnvironment('APP_BASE_URL', defaultValue: _defaultUrl);
    final appVersion = const String.fromEnvironment('APP_VERSION', defaultValue: _defaultVersion);
    final tokenParam = const String.fromEnvironment('TOKEN_PARAM_NAME', defaultValue: 'tokenId');

    final uri = Uri.parse(baseUrl);
    final params = <String, String>{...uri.queryParameters};
    params[tokenParam] = token;
    params['version'] = appVersion;
    params['tokenProvider'] = provider;
    params['platform'] = 'ios';

    return uri.replace(queryParameters: params).toString();
  }

  void _listenForNotificationOpen() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final deepLink = message.data['deep_link'];
      if (deepLink is String && deepLink.trim().isNotEmpty) {
        final uri = Uri.tryParse(deepLink);
        if (uri != null) {
          _controller.loadRequest(uri);
        }
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      final deepLink = message?.data['deep_link'];
      if (deepLink is String && deepLink.trim().isNotEmpty) {
        final uri = Uri.tryParse(deepLink);
        if (uri != null) {
          _controller.loadRequest(uri);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(body: SafeArea(child: WebViewWidget(controller: _controller)));
  }
}

class TokenResult {
  const TokenResult({required this.token, required this.provider});

  final String token;
  final String provider;
}
