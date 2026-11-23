import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_section_header.dart';
import '../../../../core/shared/widgets/status_badge.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/pago.dart';
import '../providers/payment_mutations_provider.dart';
import '../providers/pagos_provider.dart';
import '../widgets/payment_feedback.dart';

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
          _showCreateSheet(context);
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
            _showCreateSheet(context);
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
                          onEdit: () => _showEditSheet(context, items[i]),
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

  Future<void> _pickPagoDate(TextEditingController controller) async {
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
    locale: 'es_US',
    symbol: 'RD\$',
    decimalDigits: 2,
  ).format(amount);

  double _parseCurrency(String text, {double fallback = 0}) {
    final clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? fallback;
  }

  Future<void> _cambiarEstado(Pago pago, String nuevoEstado) async {
    if (pago.estado == nuevoEstado) return;
    final mutations = ref.read(paymentMutationsProvider);
    await showPaymentResult(
      context,
      () => mutations.changeStatus(pago, nuevoEstado),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final database = LocalDatabaseService();
    final mutations = ref.read(paymentMutationsProvider);
    final inquilinos = await mutations.availableTenants();
    if (!context.mounted) return;
    if (mutations.isOnline && inquilinos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sincroniza los inquilinos del CRM antes de registrar un pago.',
          ),
        ),
      );
      return;
    }
    final fechaPagoCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final montoCtrl = TextEditingController();
    int? idInquilinoSeleccionado;
    String estadoSeleccionado = 'pendiente';
    var guardando = false;

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
                const AppSectionHeader(
                  title: 'Nuevo pago',
                  icon: Icons.add_card_rounded,
                ),
                if (mutations.isOnline)
                  const Text('El pago se guarda en el CRM. Requiere conexión.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: idInquilinoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Inquilino',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Selecciona un inquilino'),
                  items: inquilinos.map((inquilino) {
                    final id = inquilino['id'] as int;
                    final nombre = (inquilino['nombre_apellido'] ?? '')
                        .toString();
                    return DropdownMenuItem(value: id, child: Text(nombre));
                  }).toList(),
                  onChanged: (id) async {
                    if (id == null) return;
                    final alquiler = await database
                        .getAlquilerActivoByInquilinoId(id);
                    if (!ctx.mounted) return;
                    setState(() {
                      idInquilinoSeleccionado = id;
                      final monto =
                          (alquiler?['montoPago'] as num?)?.toDouble() ??
                          (alquiler?['importe'] as num?)?.toDouble() ??
                          0;
                      montoCtrl.text = monto > 0 ? _currency(monto) : '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Fecha de pago',
                  hint: '2026-09-23',
                  prefixIcon: Icons.calendar_month_rounded,
                  controller: fechaPagoCtrl,
                  readOnly: true,
                  onTap: () => _pickPagoDate(fechaPagoCtrl),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Monto',
                  hint: '1650.00',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                    () => estadoSeleccionado = v ?? estadoSeleccionado,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Guardar pago',
                  isLoading: guardando,
                  onPressed: () async {
                    final fechaPago = fechaPagoCtrl.text.trim();
                    final monto = _parseCurrency(montoCtrl.text.trim());

                    if (idInquilinoSeleccionado == null || fechaPago.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Inquilino y fecha son obligatorios.'),
                        ),
                      );
                      return;
                    }

                    setState(() => guardando = true);
                    final saved = await showPaymentResult(
                      context,
                      () => mutations.create(
                        idInquilino: idInquilinoSeleccionado.toString(),
                        fechaPago: fechaPago,
                        monto: monto,
                        estado: estadoSeleccionado,
                      ),
                    );
                    if (!ctx.mounted || !sheetCtx.mounted) return;
                    setState(() => guardando = false);
                    if (saved) Navigator.of(sheetCtx).pop();
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
    final idInquilinoCtrl = TextEditingController(text: pago.idInquilino);
    final fechaPagoCtrl = TextEditingController(text: pago.fechaPago);
    final montoCtrl = TextEditingController(text: _currency(pago.monto));
    String estadoSeleccionado = pago.estado;
    var guardando = false;
    final mutations = ref.read(paymentMutationsProvider);

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
                const AppSectionHeader(
                  title: 'Editar pago',
                  icon: Icons.receipt_long_outlined,
                ),
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
                  readOnly: true,
                  onTap: () => _pickPagoDate(fechaPagoCtrl),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Monto',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                    () => estadoSeleccionado = v ?? estadoSeleccionado,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Actualizar pago',
                  isLoading: guardando,
                  onPressed: () async {
                    final monto = _parseCurrency(
                      montoCtrl.text.trim(),
                      fallback: pago.monto,
                    );
                    setState(() => guardando = true);
                    final saved = await showPaymentResult(
                      context,
                      () => mutations.update(
                        pago,
                        idInquilino: idInquilinoCtrl.text.trim(),
                        fechaPago: fechaPagoCtrl.text.trim(),
                        monto: monto,
                        estado: estadoSeleccionado,
                      ),
                    );
                    if (!ctx.mounted || !sheetCtx.mounted) return;
                    setState(() => guardando = false);
                    if (saved) Navigator.of(sheetCtx).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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
