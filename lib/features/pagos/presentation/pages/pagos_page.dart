import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/pago.dart';
import '../providers/pagos_provider.dart';

class PagosPage extends ConsumerWidget {
  const PagosPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Pagos'),
      actions: [
        IconButton(
          tooltip: 'Nuevo pago',
          onPressed: () => _showCreateDialog(context, ref),
          icon: const Icon(Icons.add_card_rounded),
        ),
      ],
    ),
    body: ref
        .watch(pagosProvider)
        .when(
          loading: () => const AppLoading(message: 'Cargando pagos...'),
          error: (_, _) => AppError(
            title: 'No pudimos cargar los pagos',
            message:
                'Verifica la conexión con el servidor e inténtalo de nuevo.',
            onRetry: () => ref.invalidate(pagosProvider),
          ),
          data: (items) => RefreshIndicator(
            onRefresh: () => ref.refresh(pagosProvider.future),
            child: items.isEmpty
                ? ListView(
                    children: const [
                      AppEmpty(title: 'No hay pagos registrados'),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PagoCard(
                              pago: item,
                              onEdit: () => _showEditDialog(context, ref, item),
                              onDelete: () => _deletePago(context, ref, item.id),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ),
  );

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, Pago pago) async {
    final idInquilinoController = TextEditingController(text: pago.idInquilino);
    final fechaPagoController = TextEditingController(text: pago.fechaPago);
    final montoController = TextEditingController(text: pago.monto.toString());
    final estadoController = TextEditingController(text: 'pendiente');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
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
                Text('Editar pago', style: AppTypography.titleMedium),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'ID inquilino',
                  prefixIcon: Icons.person_rounded,
                  keyboardType: TextInputType.number,
                  controller: idInquilinoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha de pago',
                  prefixIcon: Icons.calendar_month_rounded,
                  controller: fechaPagoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Monto',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  controller: montoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Estado',
                  prefixIcon: Icons.flag_rounded,
                  controller: estadoController,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Actualizar pago',
                  onPressed: () async {
                    final idInquilino = idInquilinoController.text.trim();
                    final fechaPago = fechaPagoController.text.trim();
                    final monto = double.tryParse(montoController.text.trim()) ?? pago.monto;
                    final estado = estadoController.text.trim().isEmpty ? 'pendiente' : estadoController.text.trim();

                    if (idInquilino.isEmpty || fechaPago.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El ID del inquilino y la fecha son obligatorios.')),
                      );
                      return;
                    }

                    final database = LocalDatabaseService();
                    await database.updatePago(
                      id: pago.id,
                      idInquilino: idInquilino,
                      fechaPago: fechaPago,
                      monto: monto,
                      estado: estado,
                    );

                    if (!context.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ref.invalidate(pagosProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pago actualizado localmente.')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final idInquilinoController = TextEditingController();
    final fechaPagoController = TextEditingController();
    final montoController = TextEditingController();
    final estadoController = TextEditingController(text: 'pendiente');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
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
                Text('Nuevo pago', style: AppTypography.titleMedium),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'ID inquilino',
                  hint: '1',
                  prefixIcon: Icons.person_rounded,
                  keyboardType: TextInputType.number,
                  controller: idInquilinoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha de pago',
                  hint: '2026-09-23',
                  prefixIcon: Icons.calendar_month_rounded,
                  controller: fechaPagoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Monto',
                  hint: '1650',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  controller: montoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Estado',
                  hint: 'pendiente o pagado',
                  prefixIcon: Icons.flag_rounded,
                  controller: estadoController,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Guardar pago',
                  onPressed: () async {
                    final idInquilino = idInquilinoController.text.trim();
                    final fechaPago = fechaPagoController.text.trim();
                    final monto = double.tryParse(montoController.text.trim()) ?? 0;
                    final estado = estadoController.text.trim();

                    if (idInquilino.isEmpty || fechaPago.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El ID del inquilino y la fecha son obligatorios.')),
                      );
                      return;
                    }

                    final database = LocalDatabaseService();
                    await database.insertPago(
                      idInquilino: idInquilino,
                      fechaPago: fechaPago,
                      monto: monto,
                      estado: estado,
                    );

                    if (!context.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ref.invalidate(pagosProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pago guardado localmente.')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePago(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: const Text('¿Deseas eliminar este pago localmente?'),
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

    await LocalDatabaseService().deletePago(id);
    if (!context.mounted) return;
    ref.invalidate(pagosProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pago eliminado localmente.')),
    );
  }
}

class _PagoCard extends StatelessWidget {
  const _PagoCard({
    required this.pago,
    required this.onEdit,
    required this.onDelete,
  });
  final Pago pago;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pago.monto.toCurrency(), style: AppTypography.currencyMedium),
        const SizedBox(height: 8),
        Text('Inquilino ID: ${pago.idInquilino}'),
        Text(
          'Fecha de pago: ${pago.fechaPago}',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
            const Spacer(),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
          ],
        ),
      ],
    ),
  );
}
