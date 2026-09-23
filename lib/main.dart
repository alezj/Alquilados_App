import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'core/shared/widgets/app_button.dart';
import 'core/shared/widgets/app_card.dart';
import 'core/shared/widgets/app_empty.dart';
import 'core/shared/widgets/app_error.dart';
import 'core/shared/widgets/app_loading.dart';
import 'core/shared/widgets/app_text_field.dart';
import 'core/shared/widgets/status_badge.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/router/app_router.dart';
import 'features/sync/data/datasources/local_database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  await LocalDatabaseService().ensureSeedData();
  runApp(const ProviderScope(child: AlquiladosApp()));
}

/// Widget principal de la aplicación.
///
/// Comparación con Angular:
/// Equivale al `AppModule` / `AppComponent` raíz con el `Theme` inyectado.
class AlquiladosApp extends StatefulWidget {
  const AlquiladosApp({super.key});

  @override
  State<AlquiladosApp> createState() => _AlquiladosAppState();
}

class _AlquiladosAppState extends State<AlquiladosApp> {
  ThemeMode _themeMode = ThemeMode.light;
  late final router = AppRouter.create(
    designSystemBuilder: (_) => DesignSystemShowcasePage(
      isDarkMode: _themeMode == ThemeMode.dark,
      onToggleTheme: _toggleTheme,
    ),
  );

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Alquilados',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      routerConfig: router,
    );
  }
}

/// Pantalla interactiva para validar visualmente el Sistema de Diseño de la Fase 2.
class DesignSystemShowcasePage extends StatefulWidget {
  const DesignSystemShowcasePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<DesignSystemShowcasePage> createState() => _DesignSystemShowcasePageState();
}

class _DesignSystemShowcasePageState extends State<DesignSystemShowcasePage> {
  bool _isLoadingButton = false;

  void _simulateAction() {
    setState(() => _isLoadingButton = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoadingButton = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alquilados — Design System'),
        actions: [
          IconButton(
            tooltip: 'Cambiar a modo ${isDarkMode ? "Claro" : "Oscuro"}',
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Encabezado de Bienvenida
              Text(
                'Fase 2: Sistema Visual',
                style: AppTypography.displayLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Componentes y tokens centralizados en Material 3.',
                style: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),

              // Sección: Badges de Estado (Inmuebles y Pagos)
              _buildSectionTitle('1. Badges de Estado (Inmuebles / Pagos)'),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(label: 'Disponible', type: StatusBadgeType.success, icon: Icons.check_circle_rounded),
                  StatusBadge(label: 'Alquilado', type: StatusBadgeType.info, icon: Icons.key_rounded),
                  StatusBadge(label: 'Mantenimiento', type: StatusBadgeType.warning, icon: Icons.build_rounded),
                  StatusBadge(label: 'En Mora', type: StatusBadgeType.error, icon: Icons.warning_rounded),
                  StatusBadge(label: 'Borrador', type: StatusBadgeType.neutral),
                ],
              ),
              const SizedBox(height: 28),

              // Sección: Cards con Ejemplos del Dominio
              _buildSectionTitle('2. AppCard (Inmueble de Ejemplo)'),
              AppCard(
                onTap: () {},
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Apartamento 4B — Torre Vista Bella',
                            style: AppTypography.titleSmall,
                          ),
                        ),
                        StatusBadge(
                          label: 'Alquilado',
                          type: StatusBadgeType.info,
                          icon: Icons.key_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text(
                          'Av. Winston Churchill #102, Piantini',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inquilino Actual',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const Text('Carlos Mendoza', style: AppTypography.bodyMedium),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Renta Mensual',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const Text(
                              '\$1,250.00',
                              style: AppTypography.currencyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Sección: Inputs de Formulario
              _buildSectionTitle('3. AppTextField (Formularios)'),
              const AppTextField(
                label: 'Correo Electrónico',
                hint: 'ejemplo@correo.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              const AppTextField(
                label: 'Contraseña',
                hint: 'Ingresa tu contraseña',
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
              ),
              const SizedBox(height: 28),

              // Sección: Botones y Estados de Carga
              _buildSectionTitle('4. AppButton (Variantes e Interacción)'),
              AppButton(
                text: _isLoadingButton ? 'Procesando...' : 'Botón Primario (Pruébame)',
                icon: Icons.send_rounded,
                isLoading: _isLoadingButton,
                onPressed: _simulateAction,
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Botón Secundario (Acento)',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Botón Delineado (Outline)',
                variant: AppButtonVariant.outline,
                onPressed: () {},
              ),
              const SizedBox(height: 28),

              // Sección: Estados de Carga, Error y Vacío
              _buildSectionTitle('5. Estados de UI (Loading / Error / Empty)'),
              const AppCard(
                child: Column(
                  children: [
                    AppLoading(message: 'Cargando listado de pagos...'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: AppError(
                  title: 'Error al conectar con la API',
                  message: 'No pudimos sincronizar los contratos. Verifica tu conexión a internet.',
                  onRetry: () {},
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: AppEmpty(
                  title: 'No hay inquilinos registrados',
                  message: 'Cuando registres un nuevo contrato, aparecerá aquí.',
                  actionText: 'Registrar Inquilino',
                  onAction: () {},
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
