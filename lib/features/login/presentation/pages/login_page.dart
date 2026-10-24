import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  String? _companyId;
  late Future<List<Map<String, dynamic>>> _companies;

  @override
  void initState() {
    super.initState();
    _companies = ref.read(supabaseAuthServiceProvider).activeCompanies();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(supabaseAuthServiceProvider);
      if (_registering) {
        if (_companyId == null)
          throw Exception('Selecciona la empresa a la que solicitas acceso.');
        await auth.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          companyId: _companyId!,
        );
        if (!mounted) return;
        setState(() => _registering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Tu acceso quedará pendiente de aprobación.',
            ),
          ),
        );
      } else {
        await auth.signIn(_email.text, _password.text);
        if (mounted) context.go(AppRoutes.dashboard);
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Image.asset(
                    'assets/app_icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _registering ? 'Solicitar acceso' : 'Iniciar sesión',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  if (_registering) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: border,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: 'Correo',
                      hintText: 'usuario@empresa.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: border,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: [
                      _registering
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: border,
                    ),
                  ),
                  if (_registering) ...[
                    const SizedBox(height: 14),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _companies,
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return const Text(
                            'No se pudieron cargar las empresas disponibles.',
                          );
                        if (!snapshot.hasData)
                          return const LinearProgressIndicator();
                        final companies = snapshot.data!;
                        return DropdownButtonFormField<String>(
                          value:
                              companies.any((item) => item['id'] == _companyId)
                                  ? _companyId
                                  : null,
                          decoration: InputDecoration(
                            labelText: 'Empresa',
                            border: border,
                          ),
                          items: companies
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item['id'].toString(),
                                  child: Text(item['name'].toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _companyId = value),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 22),
                  AppButton(
                    text: _registering ? 'Enviar solicitud' : 'Iniciar sesión',
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _registering = !_registering),
                    child: Text(
                      _registering
                          ? 'Ya tengo una cuenta'
                          : 'Solicitar incorporación a una empresa',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Políticas de aceptación
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.politicas),
                    icon: const Icon(Icons.policy_outlined),
                    label: const Text('Políticas'),
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
