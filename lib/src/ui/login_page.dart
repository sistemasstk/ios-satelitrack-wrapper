import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../config/app_config.dart';
import '../theme/app_palette.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int _userType = 1;
  bool _showPassword = false;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.controller.login(
      username: _userController.text.trim(),
      password: _passwordController.text,
      userType: _userType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xffeef6f1), Color(0xffd8ebe0), Color(0xfff7faf7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            AppConfig.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.deepGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ingreso nativo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          if ((controller.notificationSetupWarning ?? '').isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xfffff7e8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xffecd7a3)),
                              ),
                              child: Text(
                                controller.notificationSetupWarning!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff7a5a00),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          DropdownButtonFormField<int>(
                            value: _userType,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Tipo de usuario',
                            ),
                            items: const <DropdownMenuItem<int>>[
                              DropdownMenuItem<int>(value: 1, child: Text('Principal')),
                              DropdownMenuItem<int>(value: 2, child: Text('Tercero')),
                            ],
                            onChanged: controller.loggingIn
                                ? null
                                : (int? value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() => _userType = value);
                                  },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _userController,
                            enabled: !controller.loggingIn,
                            onTapOutside: (_) => FocusScope.of(context).unfocus(),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Usuario',
                            ),
                            validator: (String? value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Ingresa tu usuario';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !controller.loggingIn,
                            onTapOutside: (_) => FocusScope.of(context).unfocus(),
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Contrasena',
                              suffixIcon: IconButton(
                                onPressed: controller.loggingIn
                                    ? null
                                    : () => setState(() => _showPassword = !_showPassword),
                                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                              ),
                            ),
                            validator: (String? value) {
                              if ((value ?? '').isEmpty) {
                                return 'Ingresa tu contrasena';
                              }
                              return null;
                            },
                          ),
                          if ((controller.errorMessage ?? '').isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              controller.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: controller.loggingIn ? null : _submit,
                              child: controller.loggingIn
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.4),
                                    )
                                  : const Text('Ingresar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
