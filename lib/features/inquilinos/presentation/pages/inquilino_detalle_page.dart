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
import '../../domain/entities/inquilino.dart';
import '../providers/inquilinos_provider.dart';

class InquilinoDetallePage extends ConsumerStatefulWidget {
  const InquilinoDetallePage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<InquilinoDetallePage> createState() =>
      _InquilinoDetallePageState();
}

class _InquilinoDetallePageState extends ConsumerState<InquilinoDetallePage> {
  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    controller.text = picked.toIso8601String().split('T').first;
  }

  String _currency(double amount) => NumberFormat.currency(
    locale: 'es_DO',
    symbol: 'RD\$',
    decimalDigits: 2,
  ).format(amount);

  double _parseCurrency(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final detalleAsync = ref.watch(inquilinoDetalleProvider(widget.id));
    final pagosAsync = ref.watch(pagosDeInquilinoProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de inquilino'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              final inquilino = detalleAsync.asData?.value;
              if (inquilino != null) {
                _showEditDialog(inquilino);
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
            const AppLoading(message: 'Cargando datos del inquilino...'),
        error: (error, _) => AppError(
          title: 'Error al cargar inquilino',
          message: 'No pudimos obtener la información del inquilino.',
          onRetry: () => ref.invalidate(inquilinoDetalleProvider(widget.id)),
        ),
        data: (inquilino) {
          if (inquilino == null) {
            return const AppEmpty(
              title: 'Inquilino no encontrado',
              message: 'El registro solicitado no existe o fue eliminado.',
            );
          }

          final initials = _getInitials(inquilino.nombreApellido);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inquilino.nombreApellido,
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          _syncBadge(inquilino.syncState),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Contact & Contract Details
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos de contacto y contrato',
                      style: AppTypography.titleSmall,
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Correo electrónico',
                      value: inquilino.correo ?? 'Sin correo registrado',
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Inicio de contrato',
                      value: inquilino.fechaInicioContrato.isNotEmpty
                          ? inquilino.fechaInicioContrato
                          : 'No especificada',
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      icon: Icons.payment_rounded,
                      label: 'Día de cobro recurrente',
                      value: 'Día ${inquilino.fechaPagos} de cada mes',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Historial de Pagos
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Historial de pagos',
                          style: AppTypography.titleSmall,
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showRegisterPaymentDialog(inquilino),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Nuevo pago'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    pagosAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, _) => const Text(
                        'No pudimos cargar los pagos de este inquilino.',
                        style: AppTypography.bodySmall,
                      ),
                      data: (pagos) {
                        if (pagos.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No hay pagos registrados para este inquilino.',
                                style: TextStyle(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: pagos.map((pago) {
                            final isPagado =
                                pago.estado.toLowerCase() == 'pagado';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPagado
                                        ? Icons.check_circle_rounded
                                        : Icons.pending_actions_rounded,
                                    color: isPagado
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pago.monto.toCurrency(),
                                          style: AppTypography.titleSmall,
                                        ),
                                        Text(
                                          'Fecha: ${pago.fechaPago}',
                                          style: AppTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(
                                    label: isPagado ? 'Pagado' : 'Pendiente',
                                    type: isPagado
                                        ? StatusBadgeType.success
                                        : StatusBadgeType.warning,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botones de acción
              AppButton(
                text: 'Editar inquilino',
                icon: Icons.edit_rounded,
                onPressed: () => _showEditDialog(inquilino),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(inquilino.id),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                label: const Text(
                  'Eliminar inquilino',
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'IN';
  }

  Future<void> _showEditDialog(Inquilino inquilino) async {
    final nombreController = TextEditingController(
      text: inquilino.nombreApellido,
    );
    final correoController = TextEditingController(
      text: inquilino.correo ?? '',
    );
    final fechaInicioController = TextEditingController(
      text: inquilino.fechaInicioContrato,
    );
    final fechaPagosController = TextEditingController(
      text: inquilino.fechaPagos.toString(),
    );

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
                const Text(
                  'Editar inquilino',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nombre y apellido',
                  prefixIcon: Icons.person_rounded,
                  controller: nombreController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Correo electrónico',
                  prefixIcon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  controller: correoController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha inicio de contrato (AAAA-MM-DD)',
                  prefixIcon: Icons.calendar_today_rounded,
                  controller: fechaInicioController,
                  readOnly: true,
                  onTap: () => _pickDate(fechaInicioController),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Día de pago mensual (1-31)',
                  prefixIcon: Icons.payment_rounded,
                  keyboardType: TextInputType.number,
                  controller: fechaPagosController,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Actualizar inquilino',
                  onPressed: () async {
                    final nombre = nombreController.text.trim();
                    final fechaInicio = fechaInicioController.text.trim();
                    final fechaPagos =
                        int.tryParse(fechaPagosController.text.trim()) ??
                        inquilino.fechaPagos;

                    if (nombre.isEmpty || fechaInicio.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Nombre y fecha de inicio son obligatorios.',
                          ),
                        ),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(sheetContext);
                    final database = LocalDatabaseService();
                    await database.updateInquilino(
                      id: inquilino.id,
                      nombreApellido: nombre,
                      correo: correoController.text.trim().isEmpty
                          ? null
                          : correoController.text.trim(),
                      fechaInicioContrato: fechaInicio,
                      fechaPagos: fechaPagos,
                    );

                    if (!mounted) return;
                    navigator.pop();
                    ref.invalidate(inquilinosProvider);
                    ref.invalidate(inquilinoDetalleProvider(widget.id));
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Inquilino actualizado con éxito.'),
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
  }

  Future<void> _showRegisterPaymentDialog(Inquilino inquilino) async {
    final alquiler = await LocalDatabaseService()
        .getAlquilerActivoByInquilinoId(inquilino.id);
    if (!mounted) return;
    final monto =
        (alquiler?['montoPago'] as num?)?.toDouble() ??
        (alquiler?['importe'] as num?)?.toDouble() ??
        0;
    final montoController = TextEditingController(
      text: monto > 0 ? _currency(monto) : '',
    );
    final fechaController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );
    String selectedEstado = 'pagado';

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
                    Text(
                      'Registrar pago para ${inquilino.nombreApellido}',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Monto a pagar',
                      hint: 'RD\$1,500.00',
                      prefixIcon: Icons.attach_money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      controller: montoController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Fecha de pago (AAAA-MM-DD)',
                      prefixIcon: Icons.calendar_today_rounded,
                      controller: fechaController,
                      readOnly: true,
                      onTap: () => _pickDate(fechaController),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedEstado,
                      decoration: InputDecoration(
                        labelText: 'Estado del pago',
                        prefixIcon: const Icon(Icons.info_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pagado',
                          child: Text('Pagado'),
                        ),
                        DropdownMenuItem(
                          value: 'pendiente',
                          child: Text('Pendiente'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedEstado = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Registrar pago',
                      onPressed: () async {
                        final monto = _parseCurrency(
                          montoController.text.trim(),
                        );
                        final fecha = fechaController.text.trim();

                        if (monto <= 0 || fecha.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa un monto válido y fecha.'),
                            ),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(sheetContext);
                        await LocalDatabaseService().insertPago(
                          idInquilino: inquilino.id.toString(),
                          fechaPago: fecha,
                          monto: monto,
                          estado: selectedEstado,
                        );

                        if (!mounted) return;
                        navigator.pop();
                        ref.invalidate(pagosDeInquilinoProvider(widget.id));
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Pago registrado correctamente.'),
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
        title: const Text('Eliminar inquilino'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este inquilino? Esta acción no se puede deshacer.',
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

    await LocalDatabaseService().deleteInquilino(id);
    ref.invalidate(inquilinosProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Inquilino eliminado.')));
    context.pop();
  }
}
