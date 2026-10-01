import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/shared/widgets/status_badge.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../../domain/entities/propiedad.dart';
import '../providers/propiedades_provider.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class PropiedadesPage extends ConsumerStatefulWidget {
  const PropiedadesPage({super.key});

  @override
  ConsumerState<PropiedadesPage> createState() => _PropiedadesPageState();
}

class _PropiedadesPageState extends ConsumerState<PropiedadesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final propiedades = ref.watch(propiedadesProvider);

    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Propiedades'),
        actions: [
          IconButton(
            tooltip: 'Nueva propiedad',
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Sincronizar datos locales',
            onPressed: () async {
              await ref.read(syncStateProvider.notifier).syncNow();
              final syncResult = ref.read(syncStateProvider);
              final result = syncResult.hasValue ? syncResult.requireValue : null;
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result?.message ?? 'Sincronización finalizada.'),
                ),
              );
            },
            icon: syncState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: propiedades.when(
        loading: () => const AppLoading(message: 'Cargando propiedades...'),
        error: (error, _) => AppError(
          title: 'No pudimos cargar las propiedades',
          message: 'Verifica la conexión con el servidor e inténtalo de nuevo.',
          onRetry: () => ref.invalidate(propiedadesProvider),
        ),
        data: (items) {
          final filtered = items.where(_matchesQuery).toList(growable: false);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(propiedadesProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppTextField(
                  label: 'Buscar propiedades',
                  hint: 'Nombre o dirección',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 20),
                if (filtered.isEmpty)
                  AppEmpty(
                    title: _query.isEmpty
                        ? 'No hay propiedades registradas'
                        : 'No encontramos propiedades',
                    message: _query.isEmpty
                        ? 'Las propiedades aparecerán aquí cuando la API tenga registros.'
                        : 'Prueba con otro nombre o dirección.',
                  )
                else
                  ...filtered.map(
                    (propiedad) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PropiedadCard(
                        propiedad: propiedad,
                        onTap: () => context.push('${AppRoutes.propiedades}/${propiedad.id}'),
                        onEdit: () => _showEditDialog(propiedad),
                        onDelete: () => _deletePropiedad(propiedad.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(Propiedad propiedad) async {
    final nombreController = TextEditingController(text: propiedad.nombre);
    final direccionController = TextEditingController(text: propiedad.direccion);
    final precioController = TextEditingController(text: propiedad.precioMensual.toString());
    final notasController = TextEditingController(text: propiedad.notas);
    int selectedEstado = propiedad.estado;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Editar propiedad', style: AppTypography.titleMedium),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Nombre',
                      prefixIcon: Icons.home_rounded,
                      controller: nombreController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Dirección',
                      prefixIcon: Icons.location_on_rounded,
                      controller: direccionController,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedEstado,
                      decoration: InputDecoration(
                        labelText: 'Estado del inmueble',
                        prefixIcon: const Icon(Icons.info_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Disponible')),
                        DropdownMenuItem(value: 2, child: Text('Alquilada')),
                        DropdownMenuItem(value: 3, child: Text('Mantenimiento')),
                        DropdownMenuItem(value: 4, child: Text('Inactiva')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedEstado = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Precio mensual',
                      prefixIcon: Icons.attach_money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: precioController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Notas',
                      prefixIcon: Icons.note_alt_rounded,
                      controller: notasController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Actualizar propiedad',
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final direccion = direccionController.text.trim();
                        final precio = double.tryParse(precioController.text.trim()) ?? propiedad.precioMensual;

                        if (nombre.isEmpty || direccion.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nombre y dirección son obligatorios.')),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(sheetContext);
                        final database = LocalDatabaseService();
                        await database.updatePropiedad(
                          id: propiedad.id,
                          nombre: nombre,
                          direccion: direccion,
                          estado: selectedEstado,
                          precioMensual: precio,
                          notas: notasController.text.trim(),
                        );

                        if (!mounted) return;
                        navigator.pop();
                        ref.invalidate(propiedadesProvider);
                        ref.invalidate(propiedadDetalleProvider(propiedad.id));
                        ref.invalidate(dashboardSummaryProvider);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Propiedad actualizada localmente.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateDialog() async {
    final nombreController = TextEditingController();
    final direccionController = TextEditingController();
    final precioController = TextEditingController(text: '0');
    final notasController = TextEditingController();
    int selectedEstado = 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nueva propiedad', style: AppTypography.titleMedium),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Nombre',
                      hint: 'Apartamento centro',
                      prefixIcon: Icons.home_rounded,
                      controller: nombreController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Dirección',
                      hint: 'Calle principal 123',
                      prefixIcon: Icons.location_on_rounded,
                      controller: direccionController,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedEstado,
                      decoration: InputDecoration(
                        labelText: 'Estado inicial',
                        prefixIcon: const Icon(Icons.info_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Disponible')),
                        DropdownMenuItem(value: 2, child: Text('Alquilada')),
                        DropdownMenuItem(value: 3, child: Text('Mantenimiento')),
                        DropdownMenuItem(value: 4, child: Text('Inactiva')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedEstado = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Precio mensual',
                      hint: '1650',
                      prefixIcon: Icons.attach_money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: precioController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Notas',
                      hint: 'Detalles del inmueble',
                      prefixIcon: Icons.note_alt_rounded,
                      controller: notasController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Guardar propiedad',
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final direccion = direccionController.text.trim();
                        final precio = double.tryParse(precioController.text.trim()) ?? 0;

                        if (nombre.isEmpty || direccion.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nombre y dirección son obligatorios.')),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(sheetContext);
                        final database = LocalDatabaseService();
                        await database.insertPropiedad(
                          nombre: nombre,
                          direccion: direccion,
                          estado: selectedEstado,
                          precioMensual: precio,
                          notas: notasController.text.trim(),
                        );

                        if (!mounted) return;
                        navigator.pop();
                        ref.invalidate(propiedadesProvider);
                        ref.invalidate(dashboardSummaryProvider);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Propiedad guardada localmente.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePropiedad(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar propiedad'),
        content: const Text('¿Deseas eliminar esta propiedad localmente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await LocalDatabaseService().deletePropiedad(id);
    if (!mounted) return;
    ref.invalidate(propiedadesProvider);
    ref.invalidate(dashboardSummaryProvider);
    messenger.showSnackBar(
      const SnackBar(content: Text('Propiedad eliminada localmente.')),
    );
  }

  bool _matchesQuery(Propiedad propiedad) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty ||
        propiedad.nombre.toLowerCase().contains(query) ||
        propiedad.direccion.toLowerCase().contains(query);
  }
}

class _PropiedadCard extends StatelessWidget {
  const _PropiedadCard({
    required this.propiedad,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Propiedad propiedad;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(propiedad.nombre, style: AppTypography.titleSmall),
              ),
              _estadoBadge(propiedad.estado),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(propiedad.direccion)),
            ],
          ),
          const Divider(height: 24),
          const Text('Renta mensual', style: AppTypography.labelMedium),
          Text(
            propiedad.precioMensual.toCurrency(),
            style: AppTypography.currencyMedium,
          ),
          if (propiedad.notas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(propiedad.notas, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Editar',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  StatusBadge _estadoBadge(int estado) => switch (estado) {
    1 => const StatusBadge(label: 'Disponible', type: StatusBadgeType.success),
    2 => const StatusBadge(label: 'Alquilada', type: StatusBadgeType.info),
    3 => const StatusBadge(
      label: 'Mantenimiento',
      type: StatusBadgeType.warning,
    ),
    4 => const StatusBadge(label: 'Inactiva', type: StatusBadgeType.neutral),
    _ => StatusBadge(label: 'Estado $estado', type: StatusBadgeType.neutral),
  };
}
