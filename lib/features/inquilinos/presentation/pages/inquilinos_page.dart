import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/inquilino.dart';
import '../providers/inquilinos_provider.dart';

class InquilinosPage extends ConsumerStatefulWidget {
  const InquilinosPage({super.key});
  @override
  ConsumerState<InquilinosPage> createState() => _InquilinosPageState();
}

class _InquilinosPageState extends ConsumerState<InquilinosPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inquilinos'),
        actions: [
          IconButton(
            tooltip: 'Nuevo inquilino',
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.person_add_rounded),
          ),
        ],
      ),
      body: ref
          .watch(inquilinosProvider)
          .when(
            loading: () => const AppLoading(message: 'Cargando inquilinos...'),
            error: (_, _) => AppError(
              title: 'No pudimos cargar los inquilinos',
              message:
                  'Verifica la conexión con el servidor e inténtalo de nuevo.',
              onRetry: () => ref.invalidate(inquilinosProvider),
            ),
            data: (items) {
              final filtered = items.where(_matches).toList(growable: false);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(inquilinosProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppTextField(
                      label: 'Buscar inquilinos',
                      hint: 'Nombre o correo',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      const AppEmpty(title: 'No hay inquilinos para mostrar')
                    else
                      ...filtered.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _InquilinoCard(
                            inquilino: item,
                            onEdit: () => _showEditDialog(item),
                            onDelete: () => _deleteInquilino(item.id),
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

  Future<void> _showEditDialog(Inquilino inquilino) async {
    final nombreController = TextEditingController(text: inquilino.nombreApellido);
    final correoController = TextEditingController(text: inquilino.correo ?? '');
    final fechaInicioController = TextEditingController(text: inquilino.fechaInicioContrato);
    final fechaPagosController = TextEditingController(text: inquilino.fechaPagos.toString());

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
                Text('Editar inquilino', style: AppTypography.titleMedium),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nombre y apellido',
                  prefixIcon: Icons.person_rounded,
                  controller: nombreController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Correo',
                  prefixIcon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  controller: correoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha inicio contrato',
                  prefixIcon: Icons.calendar_month_rounded,
                  controller: fechaInicioController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Día de pago',
                  prefixIcon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                  controller: fechaPagosController,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Actualizar inquilino',
                  onPressed: () async {
                    final nombre = nombreController.text.trim();
                    final correo = correoController.text.trim();
                    final fechaInicio = fechaInicioController.text.trim();
                    final fechaPagos = int.tryParse(fechaPagosController.text.trim()) ?? inquilino.fechaPagos;

                    if (nombre.isEmpty || fechaInicio.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nombre y fecha de inicio son obligatorios.')),
                      );
                      return;
                    }

                    final database = LocalDatabaseService();
                    await database.updateInquilino(
                      id: inquilino.id,
                      nombreApellido: nombre,
                      correo: correo.isEmpty ? null : correo,
                      fechaInicioContrato: fechaInicio,
                      fechaPagos: fechaPagos,
                    );

                    if (!context.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ref.invalidate(inquilinosProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inquilino actualizado localmente.')),
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

  Future<void> _showCreateDialog() async {
    final nombreController = TextEditingController();
    final correoController = TextEditingController();
    final fechaInicioController = TextEditingController();
    final fechaPagosController = TextEditingController();

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
                Text('Nuevo inquilino', style: AppTypography.titleMedium),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nombre y apellido',
                  hint: 'Carlos Mendoza',
                  prefixIcon: Icons.person_rounded,
                  controller: nombreController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Correo',
                  hint: 'correo@ejemplo.com',
                  prefixIcon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  controller: correoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha inicio contrato',
                  hint: '2026-01-15',
                  prefixIcon: Icons.calendar_month_rounded,
                  controller: fechaInicioController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Día de pago',
                  hint: '15',
                  prefixIcon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                  controller: fechaPagosController,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Guardar inquilino',
                  onPressed: () async {
                    final nombre = nombreController.text.trim();
                    final correo = correoController.text.trim();
                    final fechaInicio = fechaInicioController.text.trim();
                    final fechaPagos = int.tryParse(fechaPagosController.text.trim()) ?? 1;

                    if (nombre.isEmpty || fechaInicio.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nombre y fecha de inicio son obligatorios.')),
                      );
                      return;
                    }

                    final database = LocalDatabaseService();
                    await database.insertInquilino(
                      nombreApellido: nombre,
                      correo: correo.isEmpty ? null : correo,
                      fechaInicioContrato: fechaInicio,
                      fechaPagos: fechaPagos,
                    );

                    if (!context.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ref.invalidate(inquilinosProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inquilino guardado localmente.')),
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

  Future<void> _deleteInquilino(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar inquilino'),
        content: const Text('¿Deseas eliminar este inquilino localmente?'),
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

    await LocalDatabaseService().deleteInquilino(id);
    if (!context.mounted) return;
    ref.invalidate(inquilinosProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inquilino eliminado localmente.')),
    );
  }

  bool _matches(Inquilino item) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty ||
        item.nombreApellido.toLowerCase().contains(query) ||
        (item.correo?.toLowerCase().contains(query) ?? false);
  }
}

class _InquilinoCard extends StatelessWidget {
  const _InquilinoCard({
    required this.inquilino,
    required this.onEdit,
    required this.onDelete,
  });
  final Inquilino inquilino;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(inquilino.nombreApellido, style: AppTypography.titleSmall),
        if (inquilino.correo?.isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          Text(inquilino.correo!),
        ],
        const SizedBox(height: 10),
        Text(
          'Inicio de contrato: ${inquilino.fechaInicioContrato}',
          style: AppTypography.bodySmall,
        ),
        Text(
          'Día de pago: ${inquilino.fechaPagos}',
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
