import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/pago.dart';
import '../providers/pagos_provider.dart';

class PagosPage extends ConsumerWidget {
  const PagosPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Pagos')),
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
                            child: _PagoCard(pago: item),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ),
  );
}

class _PagoCard extends StatelessWidget {
  const _PagoCard({required this.pago});
  final Pago pago;
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
      ],
    ),
  );
}
