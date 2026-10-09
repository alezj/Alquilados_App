import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sync/presentation/providers/sync_provider.dart';

class ConfiguracionPage extends ConsumerWidget {
  const ConfiguracionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final syncStatus = syncState.hasValue ? syncState.requireValue : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Acciones', style: AppTypography.titleMedium),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.home_rounded),
                title: const Text('Propiedades'),
                subtitle: const Text('Gestionar inmuebles y disponibilidad.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/propiedades'),
              ),
              ListTile(
                leading: const Icon(Icons.people_rounded),
                title: const Text('Inquilinos'),
                subtitle: const Text('Consultar y administrar ocupantes.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/inquilinos'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.sync_rounded),
                title: Text('Sincronización local'),
                subtitle: Text('Sincronización manual de la base SQLite local.'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppButton(
                  text: 'Sincronizar ahora',
                  icon: Icons.sync_rounded,
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
              ),

              // Boton de cerrar sesión
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.logout_rounded),
                title: Text('Cerrar sesión'),
                subtitle: Text('Cerrar la sesión actual de la aplicación.'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppButton(
                  text: 'Cerrar sesión',
                  icon: Icons.logout_rounded,
                 // isLoading: syncState.isLoading, // Deshabilitado para el botón de cerrar sesión
                  onPressed: () => context.push('/login'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Estado'),
                subtitle: Text(syncStatus?.message ?? 'Sin sincronizaciones ejecutadas.'),
              ),
              const ListTile(
                leading: Icon(Icons.dark_mode_rounded),
                title: Text('Tema'),
                subtitle: Text('Tema claro / oscuro disponible.'),
              ),
            ],
          ),
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error al obtener la información de la aplicación.'));
            } else if (snapshot.hasData) {
              final packageInfo = snapshot.data!;
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title: const Text('Versión de la aplicación'),
                  subtitle: Text('${packageInfo.version}+${packageInfo.buildNumber}'),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ],
    );
  }
}
