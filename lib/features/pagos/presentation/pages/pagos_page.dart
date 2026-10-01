import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/pago.dart';
import '../providers/pagos_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Página principal de pagos
// ──────────────────────────────────────────────────────────────────────────────

class PagosPage extends ConsumerStatefulWidget {
  const PagosPage({super.key});

  @override
  ConsumerState<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends ConsumerState<PagosPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(pagosFiltroProvider);
    final pagosAsync = ref.watch(pagosFiltradosProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos y facturas'),
        actions: [
          IconButton(
            tooltip: 'Nuevo pago',
            onPressed: () => _showCreateSheet(context),
            icon: const Icon(Icons.add_card_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de búsqueda ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppTextField(
              label: 'Buscar por inquilino, monto o estado...',
              prefixIcon: Icons.search_rounded,
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(pagosFiltroProvider.notifier).setBusqueda(v),
            ),
          ),
          // ── Filtro por estado ─────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                for (final opcion in FiltroEstadoPago.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FiltroChip(
                      label: _labelEstado(opcion),
                      selected: filtro.estado == opcion,
                      onTap: () => ref
                          .read(pagosFiltroProvider.notifier)
                          .setEstado(opcion),
                    ),
                  ),
              ],
            ),
          ),
          // ── Filtro por mes ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    filtro.yearMonth != null
                        ? 'Mes: ${filtro.yearMonth}'
                        : 'Todos los meses',
                    style: AppTypography.bodySmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _seleccionarMes(context),
                  child: const Text('Filtrar mes'),
                ),
                if (filtro.yearMonth != null)
                  IconButton(
                    tooltip: 'Quitar filtro de mes',
                    onPressed: () => ref
                        .read(pagosFiltroProvider.notifier)
                        .setYearMonth(null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Lista de pagos ────────────────────────────────────────
          Expanded(
            child: pagosAsync.when(
              loading: () => const AppLoading(message: 'Cargando pagos...'),
              error: (_, _) => AppError(
                title: 'No pudimos cargar los pagos',
                message: 'Verifica la conexión e inténtalo de nuevo.',
                onRetry: () => ref.invalidate(pagosProvider),
              ),
              data: (items) => RefreshIndicator(
                onRefresh: () => ref.refresh(pagosProvider.future),
                child: items.isEmpty
                    ? ListView(
                        children: const [
                          AppEmpty(title: 'No hay pagos que coincidan'),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _PagoCard(
                          pago: items[i],
                          onTap: () => context
                              .push('/pagos/${items[i].id}'),
                          onEdit: () =>
                              _showEditSheet(context, items[i]),
                          onDelete: () =>
                              _confirmDelete(context, items[i].id),
                          onEstadoChange: (estado) =>
                              _cambiarEstado(items[i], estado),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelEstado(FiltroEstadoPago opcion) => switch (opcion) {
        FiltroEstadoPago.todos => 'Todos',
        FiltroEstadoPago.pendiente => 'Pendientes',
        FiltroEstadoPago.pagado => 'Pagados',
        FiltroEstadoPago.vencido => 'Vencidos',
      };

  Future<void> _seleccionarMes(BuildContext context) async {
    final now = DateTime.now();
    // Generar últimos 12 meses
    final meses = [
      for (int i = 0; i < 12; i++)
        DateTime(now.year, now.month - i, 1),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Selecciona un mes',
                  style: AppTypography.titleMedium),
            ),
            ...meses.map(
              (m) {
                final key =
                    '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
                return ListTile(
                  title: Text(_formatMes(m)),
                  onTap: () => Navigator.of(ctx).pop(key),
                );
              },
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      ref.read(pagosFiltroProvider.notifier).setYearMonth(selected);
    }
  }

  String _formatMes(DateTime d) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[d.month - 1]} ${d.year}';
  }

  Future<void> _cambiarEstado(Pago pago, String nuevoEstado) async {
    await LocalDatabaseService().updatePago(
      id: pago.id,
      idInquilino: pago.idInquilino,
      fechaPago: pago.fechaPago,
      monto: pago.monto,
      estado: nuevoEstado,
    );
    ref.invalidate(pagosProvider);
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final idInquilinoCtrl = TextEditingController();
    final fechaPagoCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final montoCtrl = TextEditingController();
    String estadoSeleccionado = 'pendiente';

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
                const Text('Nuevo pago', style: AppTypography.titleMedium),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'ID inquilino',
                  hint: '1',
                  prefixIcon: Icons.person_rounded,
                  keyboardType: TextInputType.number,
                  controller: idInquilinoCtrl,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha de pago',
                  hint: '2026-09-23',
                  prefixIcon: Icons.calendar_month_rounded,
                  controller: fechaPagoCtrl,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Monto',
                  hint: '1650.00',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  controller: montoCtrl,
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
                  onChanged: (v) => setState(
                      () => estadoSeleccionado = v ?? estadoSeleccionado),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Guardar pago',
                  onPressed: () async {
                    final idInquilino = idInquilinoCtrl.text.trim();
                    final fechaPago = fechaPagoCtrl.text.trim();
                    final monto =
                        double.tryParse(montoCtrl.text.trim()) ?? 0;

                    if (idInquilino.isEmpty || fechaPago.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('ID de inquilino y fecha son obligatorios.'),
                        ),
                      );
                      return;
                    }

                    await LocalDatabaseService().insertPago(
                      idInquilino: idInquilino,
                      fechaPago: fechaPago,
                      monto: monto,
                      estado: estadoSeleccionado,
                    );
                    if (!context.mounted) return;
                    Navigator.of(sheetCtx).pop();
                    ref.invalidate(pagosProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Pago guardado localmente.')),
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

  Future<void> _showEditSheet(BuildContext context, Pago pago) async {
    final idInquilinoCtrl =
        TextEditingController(text: pago.idInquilino);
    final fechaPagoCtrl =
        TextEditingController(text: pago.fechaPago);
    final montoCtrl =
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
                AppTextField(
                  label: 'ID inquilino',
                  prefixIcon: Icons.person_rounded,
                  keyboardType: TextInputType.number,
                  controller: idInquilinoCtrl,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha de pago',
                  prefixIcon: Icons.calendar_month_rounded,
                  controller: fechaPagoCtrl,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Monto',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  controller: montoCtrl,
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
                  onChanged: (v) => setState(
                      () => estadoSeleccionado = v ?? estadoSeleccionado),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Actualizar pago',
                  onPressed: () async {
                    final monto =
                        double.tryParse(montoCtrl.text.trim()) ?? pago.monto;
                    await LocalDatabaseService().updatePago(
                      id: pago.id,
                      idInquilino: idInquilinoCtrl.text.trim(),
                      fechaPago: fechaPagoCtrl.text.trim(),
                      monto: monto,
                      estado: estadoSeleccionado,
                    );
                    if (!context.mounted) return;
                    Navigator.of(sheetCtx).pop();
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

  Future<void> _confirmDelete(BuildContext context, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pago'),
        content:
            const Text('¿Deseas eliminar este pago localmente?'),
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
    await LocalDatabaseService().deletePago(id);
    if (!context.mounted) return;
    ref.invalidate(pagosProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pago eliminado.')));
  }
}

// ── Widgets privados ─────────────────────────────────────────────────────────

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

class _PagoCard extends StatelessWidget {
  const _PagoCard({
    required this.pago,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onEstadoChange,
  });
  final Pago pago;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String estado) onEstadoChange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (estadoColor, estadoIcon) = switch (pago.estado) {
      'pagado' => (Colors.green, Icons.check_circle_rounded),
      'vencido' => (Colors.red, Icons.cancel_rounded),
      _ => (Colors.orange, Icons.schedule_rounded),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pago.monto.toCurrency(),
                      style: AppTypography.currencyMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: estadoColor.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon,
                            size: 14, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          pago.estado.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Detalles ──────────────────────────────────────
Wrap(
  spacing: 12,
  runSpacing: 4,
  children: [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.person_rounded,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Inquilino #(${pago.idInquilino}) ${pago.inquilinoNombre}',
          style: AppTypography.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_today_rounded,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          pago.fechaPago,
          style: AppTypography.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  ],
),
              // ── Detalles ──────────────────────────────────────
              // Row(
              //   children: [
              //     Icon(Icons.person_rounded,
              //         size: 14,
              //         color: colorScheme.onSurfaceVariant),
              //     const SizedBox(width: 4),
              //     Text('Inquilino #${pago.idInquilino}',
              //         style: AppTypography.bodySmall.copyWith(
              //             color: colorScheme.onSurfaceVariant)),
              //     const Spacer(),
              //     Icon(Icons.calendar_today_rounded,
              //         size: 14,
              //         color: colorScheme.onSurfaceVariant),
              //     const SizedBox(width: 4),
              //     Text(pago.fechaPago,
              //         style: AppTypography.bodySmall.copyWith(
              //             color: colorScheme.onSurfaceVariant)),
              //   ],
              // ),
              const SizedBox(height: 10),
              // ── Acciones rápidas ──────────────────────────────
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _QuickAction(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Pagado',
                        color: Colors.green,
                        active: pago.estado == 'pagado',
                        onTap: () => onEstadoChange('pagado'),
                      ),
                      _QuickAction(
                        icon: Icons.schedule_rounded,
                        label: 'Pendiente',
                        color: Colors.orange,
                        active: pago.estado == 'pendiente',
                        onTap: () => onEstadoChange('pendiente'),
                      ),
                      _QuickAction(
                        icon: Icons.cancel_outlined,
                        label: 'Vencido',
                        color: Colors.red,
                        active: pago.estado == 'vencido',
                        onTap: () => onEstadoChange('vencido'),
                      ),

                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded),
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        tooltip: 'Editar',
                      ),

                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_rounded),
                        color: colorScheme.error,
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active ? color : Colors.grey,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
