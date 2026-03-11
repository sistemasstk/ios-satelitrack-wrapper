import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/services/backend_client.dart';
import 'src/services/notification_token_service.dart';
import 'src/services/session_store.dart';
import 'src/ui/dashboard_page.dart';
import 'src/ui/login_page.dart';

Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Keep handler safe when Firebase is not available.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  } catch (_) {
    // App can run without Firebase during early setup.
  }

  runApp(const SatelitrackNativeApp());
}

class SatelitrackNativeApp extends StatefulWidget {
  const SatelitrackNativeApp({super.key});

  @override
  State<SatelitrackNativeApp> createState() => _SatelitrackNativeAppState();
}

class _SatelitrackNativeAppState extends State<SatelitrackNativeApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController(
      backendClient: BackendClient(),
      sessionStore: SessionStore(),
      notificationService: NotificationTokenService(),
    );
    unawaited(_controller.bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0d47a1)),
            appBarTheme: const AppBarTheme(centerTitle: false),
          ),
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_controller.bootstrapping) {
      return const _BootstrapPage();
    }
    if (_controller.isAuthenticated) {
      return DashboardPage(controller: _controller);
    }
    return LoginPage(controller: _controller);
  }
}

class _BootstrapPage extends StatelessWidget {
  const _BootstrapPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Cargando aplicacion...'),
          ],
        ),
      ),
    );
  }
}
