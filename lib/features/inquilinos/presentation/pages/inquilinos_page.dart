import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_empty.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/theme/app_typography.dart';
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
      appBar: AppBar(title: const Text('Inquilinos')),
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
                          child: _InquilinoCard(inquilino: item),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
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
  const _InquilinoCard({required this.inquilino});
  final Inquilino inquilino;

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
      ],
    ),
  );
}
