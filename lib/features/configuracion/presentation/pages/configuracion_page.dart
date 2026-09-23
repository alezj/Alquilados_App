import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              const Text('Configuración', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
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
      ],
    );
  }
}
