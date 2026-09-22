import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/shared/widgets/status_badge.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/propiedad.dart';
import '../providers/propiedades_provider.dart';

class PropiedadesPage extends ConsumerStatefulWidget {
  const PropiedadesPage({super.key});

  @override
  ConsumerState<PropiedadesPage> createState() => _PropiedadesPageState();
}

class _PropiedadesPageState extends ConsumerState<PropiedadesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final propiedades = ref.watch(propiedadesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Propiedades')),
      body: propiedades.when(
        loading: () => const AppLoading(message: 'Cargando propiedades...'),
        error: (error, _) => AppError(
          title: 'No pudimos cargar las propiedades',
          message: 'Verifica la conexión con el servidor e inténtalo de nuevo.',
          onRetry: () => ref.invalidate(propiedadesProvider),
        ),
        data: (items) {
          final filtered = items.where(_matchesQuery).toList(growable: false);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(propiedadesProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppTextField(
                  label: 'Buscar propiedades',
                  hint: 'Nombre o dirección',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 20),
                if (filtered.isEmpty)
                  AppEmpty(
                    title: _query.isEmpty
                        ? 'No hay propiedades registradas'
                        : 'No encontramos propiedades',
                    message: _query.isEmpty
                        ? 'Las propiedades aparecerán aquí cuando la API tenga registros.'
                        : 'Prueba con otro nombre o dirección.',
                  )
                else
                  ...filtered.map(
                    (propiedad) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PropiedadCard(propiedad: propiedad),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matchesQuery(Propiedad propiedad) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty ||
        propiedad.nombre.toLowerCase().contains(query) ||
        propiedad.direccion.toLowerCase().contains(query);
  }
}

class _PropiedadCard extends StatelessWidget {
  const _PropiedadCard({required this.propiedad});

  final Propiedad propiedad;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(propiedad.nombre, style: AppTypography.titleSmall),
              ),
              _estadoBadge(propiedad.estado),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(propiedad.direccion)),
            ],
          ),
          const Divider(height: 24),
          const Text('Renta mensual', style: AppTypography.labelMedium),
          Text(
            propiedad.precioMensual.toCurrency(),
            style: AppTypography.currencyMedium,
          ),
          if (propiedad.notas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(propiedad.notas, style: AppTypography.bodySmall),
          ],
        ],
      ),
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
}
