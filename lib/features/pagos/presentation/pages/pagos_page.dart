import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_section_header.dart';
import '../../../../core/shared/widgets/status_badge.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/pago.dart';
import '../providers/payment_mutations_provider.dart';
import '../providers/pagos_provider.dart';
import '../widgets/payment_feedback.dart';
import '../widgets/payment_form_sheet.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Página principal de pagos
// ──────────────────────────────────────────────────────────────────────────────

class PagosPage extends ConsumerStatefulWidget {
  const PagosPage({super.key, this.openCreateSheet = false});

  final bool openCreateSheet;

  @override
  ConsumerState<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends ConsumerState<PagosPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.openCreateSheet || ref.read(openCreatePagoSheetProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showPaymentForm(context);
          ref.read(openCreatePagoSheetProvider.notifier).reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(openCreatePagoSheetProvider, (prev, next) {
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showPaymentForm(context);
            ref.read(openCreatePagoSheetProvider.notifier).reset();
          }
        });
      }
    });

    final filtro = ref.watch(pagosFiltroProvider);
    final hoy = ref.watch(hoyPagosProvider);
    ref.listen(pagosFiltroProvider.select((value) => value.busqueda), (
      _,
      query,
    ) {
      if (_searchController.text != query) _searchController.text = query;
    });
    final pagosAsync = ref.watch(pagosFiltradosProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos y Facturas'),
        actions: [
          IconButton(
            tooltip: 'Nuevo pago',
            onPressed: () => showPaymentForm(context),
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
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18),

                Text(
                  filtro.yearMonth != null
                      ? 'Mes: ${filtro.yearMonth}'
                      : 'Todos los meses',
                  style: AppTypography.bodySmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _PagoCard(
                          pago: items[i],
                          isOverdue: items[i].estaVencido(hoy),
                          onTap: () => context.push('/pagos/${items[i].id}'),
                          onEdit: () =>
                              showPaymentForm(context, pago: items[i]),
                          onDelete: () => _confirmDelete(context, items[i]),
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
    FiltroEstadoPago.proximos => 'Próximos 7 días',
  };

  Future<void> _seleccionarMes(BuildContext context) async {
    final now = DateTime.now();
    // Generar últimos 12 meses
    final meses = [
      for (int i = 0; i < 12; i++) DateTime(now.year, now.month - i, 1),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: AppSectionHeader(
                title: 'Selecciona un mes',
                icon: Icons.calendar_month_outlined,
              ),
            ),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: meses.length,
                itemBuilder: (context, index) {
                  final m = meses[index];

                  final key =
                      '${m.year.toString().padLeft(4, '0')}-'
                      '${m.month.toString().padLeft(2, '0')}';

                  return ListTile(
                    title: Text(_formatMes(m)),
                    onTap: () => Navigator.of(ctx).pop(key),
                  );
                },
              ),
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
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${meses[d.month - 1]} ${d.year}';
  }

  Future<void> _cambiarEstado(Pago pago, String nuevoEstado) async {
    if (pago.estado == nuevoEstado) return;
    final mutations = ref.read(paymentMutationsProvider);
    await showPaymentResult(
      context,
      () => mutations.changeStatus(pago, nuevoEstado),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Pago pago) async {
    final mutations = ref.read(paymentMutationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: Text(
          mutations.isOnline
              ? '¿Deseas eliminar este pago del CRM?'
              : '¿Deseas eliminar este pago localmente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await showPaymentResult(context, () => mutations.delete(pago));
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
    required this.isOverdue,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onEstadoChange,
  });
  final Pago pago;
  final bool isOverdue;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String estado) onEstadoChange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estadoVisible = isOverdue ? 'vencido' : pago.estadoNormalizado;
    final tenantName = pago.inquilinoNombre.trim();
    return AppCard(
      borderRadius: 18,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSectionHeader(
                  title: tenantName.isEmpty
                      ? 'Inquilino #${pago.idInquilino}'
                      : tenantName,
                  subtitle: pago.fechaPago.isEmpty ? null : pago.fechaPago,
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Acciones del pago',
                onSelected: (edit) => edit ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: true, child: Text('Editar pago')),
                  PopupMenuItem(value: false, child: Text('Eliminar pago')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                pago.monto.toCurrency(),
                style: AppTypography.currencyMedium.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              StatusBadge.fromString(estadoVisible),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final (value, label) in const [
                ('pagado', 'Pagado'),
                ('pendiente', 'Pendiente'),
                ('vencido', 'Vencido'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: pago.estadoNormalizado == value,
                  showCheckmark: false,
                  onSelected: (_) => onEstadoChange(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
