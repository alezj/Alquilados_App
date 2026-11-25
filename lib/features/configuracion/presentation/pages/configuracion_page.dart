import '../../../notificaciones/data/payment_notification_service.dart';
import '../../../../core/config/app_config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_section_header.dart';
import '../../../../core/theme/app_typography.dart';
import '../widgets/appearance_settings.dart';
import '../../../sync/presentation/providers/sync_provider.dart';

class ConfiguracionPage extends ConsumerWidget {
  const ConfiguracionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final syncStatus = syncState.hasValue ? syncState.requireValue : null;

    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Column(
            children: [
              const AppSectionHeader(
                title: 'Gestión',
                icon: Icons.domain_outlined,
              ),
              const SizedBox(height: 8),
              _action(
                'Propiedades',
                Icons.home_work_outlined,
                () => context.push('/propiedades'),
              ),
              _action(
                'Inquilinos',
                Icons.people_outline_rounded,
                () => context.push('/inquilinos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: 'Sincronización',
                icon: Icons.cloud_sync_outlined,
                subtitle: syncState.isLoading
                    ? 'Sincronizando…'
                    : syncStatus?.message ??
                          (syncState.hasError
                              ? 'No se pudo completar la sincronización.'
                              : 'Sin sincronizaciones ejecutadas.'),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Sincronizar ahora',
                icon: Icons.sync_rounded,
                variant: AppButtonVariant.secondary,
                isLoading: syncState.isLoading,
                onPressed: () async {
                  await ref.read(syncStateProvider.notifier).syncNow();
                  if (!context.mounted) return;
                  final result = ref.read(syncStateProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.hasValue
                            ? result.requireValue.message
                            : 'No se pudo completar la sincronización.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            children: [
              const AppSectionHeader(
                title: 'Cuenta y preferencias',
                icon: Icons.manage_accounts_outlined,
              ),
              const SizedBox(height: 8),
              const AppearanceSettings(),
              FutureBuilder<Map<String, dynamic>?>(
                future: ref.read(secureStorageProvider).getSessionContext(),
                builder: (context, snapshot) {
                  final username = snapshot.data?['username']?.toString() ?? '';
                  if (!AppConfig.canChooseEnvironment(username))
                    return const SizedBox.shrink();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: const Text('Cambiar ambiente'),
                    subtitle: Text(
                      AppConfig.backend == BackendEnvironment.test
                          ? 'Pruebas (Alquilados_Test)'
                          : 'Producción',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await PaymentNotificationService.instance.cancel();
                      await ref.read(supabaseAuthServiceProvider).signOut();
                      if (context.mounted)
                        context.go('/login?usuario=Johancel');
                    },
                  );
                },
              ),
              _PaymentNotificationSettings(),
              _action(
                'Políticas',
                Icons.policy_outlined,
                () => context.push(AppRoutes.politicas),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded, color: colors.error),
                title: Text(
                  'Cerrar sesión',
                  style: TextStyle(color: colors.error),
                ),
                onTap: () async {
                  await PaymentNotificationService.instance.cancel();
                  await ref.read(supabaseAuthServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            if (info == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Alquilados ${info.version}+${info.buildNumber}',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _action(String title, IconData icon, VoidCallback onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _PaymentNotificationSettings extends StatefulWidget {
  @override
  State<_PaymentNotificationSettings> createState() =>
      _PaymentNotificationSettingsState();
}

class _PaymentNotificationSettingsState
    extends State<_PaymentNotificationSettings> {
  bool _enabled = false;
  bool _busy = true;
  final _service = PaymentNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _service
        .isEnabled()
        .then((enabled) {
          if (mounted) {
            setState(() {
              _enabled = enabled;
              _busy = false;
            });
          }
        })
        .catchError((Object error) {
          if (mounted) setState(() => _busy = false);
        });
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: const Icon(Icons.notifications_active_outlined),
    title: const Text('Avisos de pagos'),
    subtitle: Text(
      _service.supported
          ? 'A las 9:00 a. m. del teléfono: día de pago y al vencer la prórroga. Los avisos se renuevan al abrir la app.'
          : 'Los avisos programados están disponibles en Android y iOS.',
    ),
    value: _enabled,
    onChanged: _busy || !_service.supported
        ? null
        : (value) async {
            setState(() => _busy = true);
            try {
              final enabled = await _service.setEnabled(value);
              if (!context.mounted) return;
              setState(() => _enabled = enabled);
              if ((value && !enabled) || _service.lastError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _service.lastError ?? 'Permite las notificaciones en los ajustes del teléfono para recibir los avisos.',
                    ),
                  ),
                );
              }
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudieron configurar los avisos: $error',
                    ),
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
  );
}
