import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/status_badge.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../pagos/domain/entities/pago.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/alquiler.dart';

class AlquilerDetallePage extends ConsumerWidget {
  const AlquilerDetallePage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: LocalDatabaseService().getAlquilerById(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('No se encontró el alquiler solicitado.')),
          );
        }

        final alquiler = Alquiler.fromMap(snapshot.data!);
        final propertyName = alquiler.propiedadNombre ?? 'Propiedad sin nombre';
        final tenantName = alquiler.inquilinoNombre ?? 'Inquilino sin asignar';

        return Scaffold(
          appBar: AppBar(title: const Text('Detalle del alquiler')),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: LocalDatabaseService().getPagosByAlquilerId(
              id,
              inquilinoId: alquiler.inquilinoId,
            ),
            builder: (context, pagosSnapshot) {
              final pagos = (pagosSnapshot.data ?? [])
                  .map((row) => Pago(
                        id: (row['id'] as num?)?.toInt() ?? 0,
                        idInquilino: (row['id_inquilino'] ?? alquiler.inquilinoId.toString()).toString(),
                        inquilinoNombre: tenantName,
                        fechaPago: (row['fecha_pago'] ?? '').toString(),
                        monto: _parseDouble(row['monto']),
                        estado: (row['estado'] ?? 'pendiente').toString(),
                        syncState: (row['sync_state'] ?? 'pending').toString(),
                        syncedAt: row['synced_at']?.toString(),
                      ))
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Información del alquiler',
                                  style: AppTypography.titleMedium,
                                ),
                              ),
                              StatusBadge.fromString(alquiler.estado),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(label: 'Propiedad', value: propertyName),
                          _InfoRow(label: 'Inquilino', value: tenantName),
                          _InfoRow(label: 'Fecha de inicio', value: _formatDate(alquiler.fechaInicio)),
                          _InfoRow(label: 'Fecha de finalización', value: _formatDate(alquiler.fechaFin)),
                          _InfoRow(label: 'Importe', value: _currency(alquiler.importe)),
                          _InfoRow(label: 'Estado', value: alquiler.estado),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Información de pagos', style: AppTypography.titleMedium),
                          const SizedBox(height: 12),
                          if (pagos.isEmpty)
                            const Text('No hay pagos registrados para este alquiler.')
                          else ...[
                            DataTable(
                              columns: const [
                                DataColumn(label: Text('Fecha')),
                                DataColumn(label: Text('Periodo')),
                                DataColumn(label: Text('Importe')),
                                DataColumn(label: Text('Estado')),
                              ],
                              rows: pagos.map((pago) {
                                return DataRow(cells: [
                                  DataCell(Text(_formatDate(pago.fechaPago))),
                                  DataCell(Text(_periodoFromDate(pago.fechaPago))),
                                  DataCell(Text(_currency(pago.monto))),
                                  DataCell(StatusBadge.fromString(pago.estado)),
                                ]);
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _periodoFromDate(String value) {
    if (value.isEmpty) return 'Sin periodo';
    try {
      final date = DateTime.parse(value);
      final month = DateFormat('MMMM', 'es').format(date);
      return month[0].toUpperCase() + month.substring(1);
    } catch (_) {
      return 'Sin periodo';
    }
  }

  static String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'Sin fecha';
    try {
      final date = DateTime.parse(value);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return value;
    }
  }

  static String _currency(double amount) {
    final format = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$', decimalDigits: 2);
    return format.format(amount);
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: AppTypography.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}
