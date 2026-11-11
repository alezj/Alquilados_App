import '../../../../core/config/app_config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/network_providers.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../propiedades/presentation/providers/propiedades_provider.dart';
import '../../../inquilinos/presentation/providers/inquilinos_provider.dart';
import '../../../alquileres/presentation/providers/alquileres_provider.dart';
import '../../../pagos/presentation/providers/pagos_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.initialUsername = ''});

  final String initialUsername;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  BackendEnvironment _environment = BackendEnvironment.test;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  String? _companyId;
  late Future<List<Map<String, dynamic>>> _companies;

  @override
  void initState() {
    super.initState();
    _username.text = widget.initialUsername;
    _companies = Future.value([]);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(supabaseAuthServiceProvider);
      if (_registering) {
        if (_companyId == null) {
          throw Exception('Selecciona la empresa a la que solicitas acceso.');
        }
        await auth.signUp(
          name: _name.text,
          username: _username.text,
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
        await auth.signIn(
          _username.text,
          _password.text,
          environment: _environment,
        );
        ref.invalidate(apiClientProvider);
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(propiedadesProvider);
        ref.invalidate(propiedadDetalleProvider);
        ref.invalidate(inquilinosProvider);
        ref.invalidate(inquilinoDetalleProvider);
        ref.invalidate(pagosDeInquilinoProvider);
        ref.invalidate(alquileresProvider);
        ref.invalidate(pagosProvider);
        ref.invalidate(pagoDetalleProvider);
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
                    controller: _username,
                    enabled: !_loading,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.username],
                    onChanged: (_) => setState(() {
                      _environment = BackendEnvironment.test;
                    }),
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: border,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!_registering &&
                      AppConfig.canChooseEnvironment(_username.text)) ...[
                    DropdownButtonFormField<BackendEnvironment>(
                      isExpanded: true,
                      key: ValueKey(_environment),
                      initialValue: _environment,
                      decoration: InputDecoration(
                        labelText: 'Ambiente',
                        border: border,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: BackendEnvironment.test,
                          child: Text('Pruebas (Alquilados_Test)'),
                        ),
                        DropdownMenuItem(
                          value: BackendEnvironment.production,
                          child: Text('Producción'),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) => setState(() {
                              _environment = value ?? BackendEnvironment.test;
                            }),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_registering)
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
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
                        if (snapshot.hasError) {
                          return const Text(
                            'No se pudieron cargar las empresas disponibles.',
                          );
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final companies = snapshot.data!;
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
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
                        : () => setState(() {
                            _registering = !_registering;
                            if (_registering) {
                              AppConfig.backend = BackendEnvironment.production;
                              ref.invalidate(supabaseAuthServiceProvider);
                              _companyId = null;
                              _companies = ref
                                  .read(supabaseAuthServiceProvider)
                                  .activeCompanies();
                            }
                          }),
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
