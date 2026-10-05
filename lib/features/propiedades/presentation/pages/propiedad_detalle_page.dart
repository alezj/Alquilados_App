import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/shared/widgets/status_badge.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/propiedad.dart';
import '../providers/propiedades_provider.dart';

String _currency(double amount) => NumberFormat.currency(
  locale: 'es_DO',
  symbol: 'RD\$',
  decimalDigits: 2,
).format(amount);

double _parseCurrency(String text, {double fallback = 0}) {
  final clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(clean) ?? fallback;
}

class PropiedadDetallePage extends ConsumerStatefulWidget {
  const PropiedadDetallePage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<PropiedadDetallePage> createState() =>
      _PropiedadDetallePageState();
}

class _PropiedadDetallePageState extends ConsumerState<PropiedadDetallePage> {
  @override
  Widget build(BuildContext context) {
    final detalleAsync = ref.watch(propiedadDetalleProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de propiedad'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              final propiedad = detalleAsync.asData?.value;
              if (propiedad != null) {
                _showEditDialog(propiedad);
              }
            },
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            onPressed: () => _confirmDelete(widget.id),
          ),
        ],
      ),
      body: detalleAsync.when(
        loading: () =>
            const AppLoading(message: 'Cargando detalles de la propiedad...'),
        error: (error, _) => AppError(
          title: 'Error al cargar la propiedad',
          message: 'No pudimos obtener la información del inmueble.',
          onRetry: () => ref.invalidate(propiedadDetalleProvider(widget.id)),
        ),
        data: (propiedad) {
          if (propiedad == null) {
            return const AppEmpty(
              title: 'Propiedad no encontrada',
              message: 'El registro solicitado no existe o fue eliminado.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Encabezado Principal
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.apartment_rounded,
                            size: 30,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                propiedad.nombre,
                                style: AppTypography.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _estadoBadge(propiedad.estado),
                                  const SizedBox(width: 8),
                                  _syncBadge(propiedad.syncState),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Selector Rápido de Estado
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cambio rápido de estado',
                      style: AppTypography.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStateChip(
                          label: 'Disponible',
                          estadoValor: 1,
                          actual: propiedad.estado,
                          color: AppColors.success,
                        ),
                        _buildStateChip(
                          label: 'Alquilada',
                          estadoValor: 2,
                          actual: propiedad.estado,
                          color: AppColors.info,
                        ),
                        _buildStateChip(
                          label: 'Mantenimiento',
                          estadoValor: 3,
                          actual: propiedad.estado,
                          color: AppColors.warning,
                        ),
                        _buildStateChip(
                          label: 'Inactiva',
                          estadoValor: 4,
                          actual: propiedad.estado,
                          color: AppColors.textMutedLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Información Económica
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información Económica',
                      style: AppTypography.titleSmall,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Renta mensual',
                              style: AppTypography.labelMedium,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Cobro recurrente',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          propiedad.precioMensual.toCurrency(),
                          style: AppTypography.currencyMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ingreso anual estimado',
                          style: AppTypography.bodyMedium,
                        ),
                        Text(
                          (propiedad.precioMensual * 12).toCurrency(),
                          style: AppTypography.titleSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ubicación y Dirección
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ubicación', style: AppTypography.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            propiedad.direccion.isNotEmpty
                                ? propiedad.direccion
                                : 'Sin dirección especificada',
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notas y Observaciones
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notas y Observaciones',
                      style: AppTypography.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      propiedad.notas.isNotEmpty ? propiedad.notas : 'No hay notas adicionales registradas para este inmueble.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: propiedad.notas.isNotEmpty
                            ? null
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botones de acción principales
              AppButton(
                text: 'Editar información',
                icon: Icons.edit_rounded,
                onPressed: () => _showEditDialog(propiedad),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(propiedad.id),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                label: const Text(
                  'Eliminar propiedad',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStateChip({
    required String label,
    required int estadoValor,
    required int actual,
    required Color color,
  }) {
    final isSelected = estadoValor == actual;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withAlpha(50),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? color : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : AppColors.borderLight,
        width: isSelected ? 1.5 : 1,
      ),
      onSelected: (selected) async {
        if (!selected || isSelected) return;
        await LocalDatabaseService().updatePropiedadEstado(
          widget.id,
          estadoValor,
        );
        ref.invalidate(propiedadDetalleProvider(widget.id));
        ref.invalidate(propiedadesProvider);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a "$label".')),
        );
      },
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

  Widget _syncBadge(String syncState) {
    if (syncState == 'synced') {
      return const StatusBadge(
        label: 'Sincronizado',
        type: StatusBadgeType.success,
        icon: Icons.cloud_done_rounded,
      );
    }
    return const StatusBadge(
      label: 'Pendiente local',
      type: StatusBadgeType.warning,
      icon: Icons.cloud_queue_rounded,
    );
  }

  Future<void> _showEditDialog(Propiedad propiedad) async {
    final nombreController = TextEditingController(text: propiedad.nombre);
    final direccionController = TextEditingController(
      text: propiedad.direccion,
    );
    final precioController = TextEditingController(
      text: _currency(propiedad.precioMensual),
    );
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
                    const Text(
                      'Editar propiedad',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Nombre de la propiedad',
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Disponible')),
                        DropdownMenuItem(value: 2, child: Text('Alquilada')),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('Mantenimiento'),
                        ),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      controller: precioController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Notas adicionales',
                      prefixIcon: Icons.note_alt_rounded,
                      controller: notasController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Guardar cambios',
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final direccion = direccionController.text.trim();
                        final precio = _parseCurrency(
                          precioController.text.trim(),
                          fallback: propiedad.precioMensual,
                        );

                        if (nombre.isEmpty || direccion.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nombre y dirección son obligatorios.',
                              ),
                            ),
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
                        ref.invalidate(propiedadDetalleProvider(widget.id));
                        ref.invalidate(propiedadesProvider);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Propiedad actualizada con éxito.'),
                          ),
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

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar propiedad'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta propiedad? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await LocalDatabaseService().deletePropiedad(id);
    ref.invalidate(propiedadesProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Propiedad eliminada.')));
    context.pop();
  }
}
