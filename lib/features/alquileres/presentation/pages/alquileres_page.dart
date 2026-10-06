import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/shared/widgets/status_badge.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/alquiler.dart';
import '../providers/alquileres_provider.dart';
import '../widgets/alquiler_form_sheet.dart';

class AlquileresPage extends ConsumerStatefulWidget {
  const AlquileresPage({super.key});

  @override
  ConsumerState<AlquileresPage> createState() => _AlquileresPageState();
}

class _AlquileresPageState extends ConsumerState<AlquileresPage> {
  @override
  Widget build(BuildContext context) {
    final alquileresAsync = ref.watch(alquileresProvider);
    final filtro = ref.watch(alquileresFiltroProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alquileres'),
        actions: [
          IconButton(
            tooltip: 'Nuevo alquiler',
            onPressed: () => _openAlquilerSheet(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: alquileresAsync.when(
        loading: () => const AppLoading(message: 'Cargando alquileres...'),
        error: (error, stackTrace) => AppError(
          title: 'No pudimos cargar los alquileres',
          message: 'Verifica la base de datos local e inténtalo de nuevo.',
          onRetry: () => ref.invalidate(alquileresProvider),
        ),
        data: (items) {
          final filtered = items.where((alquiler) {
            final busqueda = filtro.busqueda.trim().toLowerCase();
            final matchesSearch = busqueda.isEmpty ||
                alquiler.propiedadNombre?.toLowerCase().contains(busqueda) == true ||
                alquiler.inquilinoNombre?.toLowerCase().contains(busqueda) == true ||
                alquiler.estado.toLowerCase().contains(busqueda);
            final matchesEstado = filtro.estado == 'todos' ||
                alquiler.estado.toLowerCase() == filtro.estado.toLowerCase();
            return matchesSearch && matchesEstado;
          }).toList(growable: false);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(alquileresProvider.future),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AppTextField(
                    label: 'Buscar por propiedad, inquilino o estado',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (value) => ref
                        .read(alquileresFiltroProvider.notifier)
                        .actualizarBusqueda(value),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      for (final estado in ['todos', 'activo', 'finalizado', 'pendiente', 'cancelado'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_estadoLabel(estado)),
                            selected: filtro.estado == estado,
                            onSelected: (_) => ref
                                .read(alquileresFiltroProvider.notifier)
                                .actualizarEstado(estado),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const AppEmpty(title: 'No hay alquileres para mostrar')
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final alquiler = filtered[index];
                            return AppCard(
                              onTap: () => context.push('${AppRoutes.alquileres}/${alquiler.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            alquiler.propiedadNombre ?? 'Propiedad sin nombre',
                                            style: AppTypography.titleSmall,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              tooltip: 'Editar alquiler',
                                              icon: const Icon(Icons.edit_rounded, size: 18),
                                              onPressed: () => _openAlquilerSheet(context, alquiler: alquiler),
                                            ),
                                            IconButton(
                                              tooltip: 'Eliminar alquiler',
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                              onPressed: () => _deleteAlquiler(alquiler.id),
                                            ),
                                            StatusBadge.fromString(alquiler.estado),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline_rounded, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            alquiler.inquilinoNombre ?? 'Inquilino sin asignar',
                                            style: AppTypography.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_formatDate(alquiler.fechaInicio)} - ${_formatDate(alquiler.fechaFin ?? 'Sin fecha fin')}',
                                      style: AppTypography.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Monto a pagar: ${_currency(alquiler.montoPago)}',
                                      style: AppTypography.currencyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAlquilerSheet(BuildContext context, {Alquiler? alquiler}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AlquilerFormSheet(alquiler: alquiler),
    );

    if (result == true) {
      ref.invalidate(alquileresProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alquiler == null ? 'Alquiler creado localmente.' : 'Alquiler actualizado localmente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteAlquiler(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar alquiler'),
        content: const Text('¿Deseas eliminar este alquiler localmente?'),
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

    await LocalDatabaseService().deleteAlquiler(id);
    ref.invalidate(alquileresProvider);
    ref.invalidate(dashboardSummaryProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alquiler eliminado localmente.')),
    );
  }

  String _estadoLabel(String key) => switch (key) {
        'todos' => 'Todos',
        'activo' => 'Activos',
        'finalizado' => 'Finalizados',
        'pendiente' => 'Pendientes',
        'cancelado' => 'Cancelados',
        _ => 'Todos',
      };

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'No disponible';

    try {
      final date = DateTime.parse(value);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return value;
    }
  }

  String _currency(double amount) {
    final format = NumberFormat.currency(locale: 'en_US', symbol: 'RD\$', decimalDigits: 2);
    return format.format(amount);
  }
}
