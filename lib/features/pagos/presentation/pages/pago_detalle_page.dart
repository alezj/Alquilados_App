import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../inquilinos/presentation/providers/inquilinos_provider.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../data/services/comprobante_pago_service.dart';
import '../../domain/entities/comprobante_pago.dart';
import '../../domain/entities/pago.dart';
import '../providers/pagos_provider.dart';

class PagoDetallePage extends ConsumerWidget {
  const PagoDetallePage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagoAsync = ref.watch(pagoDetalleProvider(id));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pago'),
        actions: [
          pagoAsync.whenOrNull(
                data: (pago) => pago == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Editar pago',
                        onPressed: () =>
                            _showEditSheet(context, ref, pago),
                        icon: const Icon(Icons.edit_rounded),
                      ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: pagoAsync.when(
        loading: () => const AppLoading(message: 'Cargando pago...'),
        error: (_, _) => AppError(
          title: 'No pudimos cargar el pago',
          message: 'Verifica tu conexión e inténtalo de nuevo.',
          onRetry: () => ref.invalidate(pagoDetalleProvider(id)),
        ),
        data: (pago) {
          if (pago == null) {
            return const Center(child: Text('Pago no encontrado.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Monto destacado ──────────────────────────────
                _SectionCard(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            pago.monto.toCurrency(),
                            style: AppTypography.currencyLarge.copyWith(
                              color: colorScheme.primary,
                              fontSize: 42,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _EstadoChip(estado: pago.estado),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Información del pago ─────────────────────────
                const Text('Información del pago',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                _SectionCard(
                  children: [
                    _InfoRow(
                      icon: Icons.tag_rounded,
                      label: 'ID',
                      value: '#${pago.id}',
                    ),
                    _InfoRow(
                      icon: Icons.person_rounded,
                      label: 'Inquilino ID',
                      value: pago.idInquilino,
                    ),
                    _InfoRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Fecha de pago',
                      value: pago.fechaPago,
                    ),
                    _InfoRow(
                      icon: Icons.flag_rounded,
                      label: 'Estado',
                      value: pago.estado,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Sincronización ───────────────────────────────
                const Text('Sincronización', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                _SectionCard(
                  children: [
                    _InfoRow(
                      icon: Icons.cloud_sync_rounded,
                      label: 'Estado de sync',
                      value: pago.syncState,
                    ),
                    _InfoRow(
                      icon: Icons.update_rounded,
                      label: 'Última sync',
                      value: pago.syncedAt ?? 'Sin sincronizar',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ── Cambio rápido de estado ──────────────────────
                const Text('Cambiar estado', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final estado in ['pendiente', 'pagado', 'vencido'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _EstadoButton(
                            label: estado,
                            isActive: pago.estado == estado,
                            onTap: () async {
                              await LocalDatabaseService().updatePago(
                                id: pago.id,
                                idInquilino: pago.idInquilino,
                                fechaPago: pago.fechaPago,
                                monto: pago.monto,
                                estado: estado,
                              );
                              ref.invalidate(pagoDetalleProvider(pago.id));
                              ref.invalidate(pagosProvider);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // ── Comprobante ─────────────────────────────────
                AppButton(
                  text: 'Generar comprobante',
                  icon: Icons.receipt_long_rounded,
                  onPressed: () => _generarComprobante(context, ref, pago),
                ),
                const SizedBox(height: 16),
                // ── Eliminar ─────────────────────────────────────
                AppButton(
                  text: 'Eliminar pago',
                  icon: Icons.delete_rounded,
                  variant: AppButtonVariant.danger,
                  onPressed: () => _confirmDelete(context, ref, pago.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditSheet(
      BuildContext context, WidgetRef ref, Pago pago) async {
    final idInquilinoController =
        TextEditingController(text: pago.idInquilino);
    final fechaPagoController =
        TextEditingController(text: pago.fechaPago);
    final montoController =
        TextEditingController(text: pago.monto.toString());
    String estadoSeleccionado = pago.estado;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Editar pago', style: AppTypography.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: idInquilinoController,
                  decoration: const InputDecoration(
                    labelText: 'ID inquilino',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fechaPagoController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de pago',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                    border: OutlineInputBorder(),
                    hintText: '2026-09-15',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: montoController,
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: estadoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    prefixIcon: Icon(Icons.flag_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: ['pendiente', 'pagado', 'vencido']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => estadoSeleccionado = v ?? estadoSeleccionado),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Guardar cambios',
                  onPressed: () async {
                    final monto =
                        double.tryParse(montoController.text.trim()) ??
                            pago.monto;
                    await LocalDatabaseService().updatePago(
                      id: pago.id,
                      idInquilino: idInquilinoController.text.trim(),
                      fechaPago: fechaPagoController.text.trim(),
                      monto: monto,
                      estado: estadoSeleccionado,
                    );
                    if (!context.mounted) return;
                    Navigator.of(sheetCtx).pop();
                    ref.invalidate(pagoDetalleProvider(pago.id));
                    ref.invalidate(pagosProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Pago actualizado localmente.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generarComprobante(
    BuildContext context,
    WidgetRef ref,
    Pago pago,
  ) async {
    final inquilinoId = int.tryParse(pago.idInquilino);
    final inquilino = inquilinoId == null
        ? null
        : await ref.read(inquilinoDetalleProvider(inquilinoId).future);

    final comprobante = ComprobantePagoData.fromPayment(pago, inquilino);

    if (!context.mounted) return;

    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.9,
            child: PdfPreview(
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              build: (format) async =>
                  ComprobantePagoService().generatePdfBytes(comprobante),
            ),
          ),
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante listo para revisar, imprimir o compartir.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el comprobante: $error'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, int pagoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: const Text('¿Deseas eliminar este pago? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalDatabaseService().deletePago(pagoId);
    if (!context.mounted) return;
    ref.invalidate(pagosProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pago eliminado.')),
    );
  }
}

// ── Widgets privados ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: AppTypography.bodySmall
                    .copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (estado) {
      'pagado' => (Colors.green, Icons.check_circle_rounded),
      'vencido' => (Colors.red, Icons.cancel_rounded),
      _ => (Colors.orange, Icons.schedule_rounded),
    };
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(estado.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      backgroundColor: color.withAlpha(25),
      side: BorderSide(color: color.withAlpha(80)),
    );
  }
}

class _EstadoButton extends StatelessWidget {
  const _EstadoButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (label) {
      'pagado' => Colors.green,
      'vencido' => Colors.red,
      _ => Colors.orange,
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(30) : colorScheme.surfaceContainerLow,
          border: Border.all(
            color: isActive ? color : colorScheme.outlineVariant,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? color : colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
