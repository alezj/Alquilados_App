import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_text_field.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FlutterLogo(size: 90),
                  const SizedBox(height: 24),
                  const AppTextField(
                    label: 'Correo',
                    hint: 'usuario@alquilados.com',
                    prefixIcon: Icons.email_rounded,
                  ),
                  const SizedBox(height: 16),
                  const AppTextField(
                    label: 'Contraseña',
                    hint: '********',
                    prefixIcon: Icons.lock_rounded,
                    isPassword: true,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    text: 'Iniciar sesión',
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/dashboard');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
