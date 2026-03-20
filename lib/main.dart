import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/services/backend_client.dart';
import 'src/services/notification_token_service.dart';
import 'src/services/session_store.dart';
import 'src/theme/app_palette.dart';
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
  bool firebaseReady = false;
  String? firebaseBootstrapError;

  try {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    firebaseReady = true;
  } catch (ex) {
    // App can still run, but push notifications will stay unavailable.
    firebaseBootstrapError = ex.toString();
  }

  runApp(
    SatelitrackNativeApp(
      firebaseReady: firebaseReady,
      firebaseBootstrapError: firebaseBootstrapError,
    ),
  );
}

class SatelitrackNativeApp extends StatefulWidget {
  const SatelitrackNativeApp({
    super.key,
    required this.firebaseReady,
    this.firebaseBootstrapError,
  });

  final bool firebaseReady;
  final String? firebaseBootstrapError;

  @override
  State<SatelitrackNativeApp> createState() => _SatelitrackNativeAppState();
}

class _SatelitrackNativeAppState extends State<SatelitrackNativeApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController(
      backendClient: BackendClient(),
      sessionStore: SessionStore(),
      notificationService: NotificationTokenService(
        firebaseReady: widget.firebaseReady,
        bootstrapError: widget.firebaseBootstrapError,
      ),
    );
    _controller.onSessionInvalidated = () {
      _navigatorKey.currentState?.popUntil((Route<dynamic> route) => route.isFirst);
    };
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
          navigatorKey: _navigatorKey,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.seed),
            scaffoldBackgroundColor: AppPalette.appBackground,
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              backgroundColor: Colors.white,
              foregroundColor: AppPalette.deepGreen,
              surfaceTintColor: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppPalette.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppPalette.borderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppPalette.seed, width: 1.4),
              ),
            ),
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
    return Scaffold(
      backgroundColor: AppPalette.appBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppPalette.seed),
            ),
            SizedBox(height: 12),
            Text(
              'Cargando aplicacion...',
              style: TextStyle(color: AppPalette.deepGreen),
            ),
          ],
        ),
      ),
    );
  }
}
