import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sync/data/datasources/local_database_service.dart';

final dashboardSummaryProvider = FutureProvider<Map<String, int>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();
  return database.getDashboardSummary();
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);

    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('No pudimos cargar el resumen.')),
      data: (data) {
        final stats = [
          _StatCard(title: 'Propiedades', value: '${data['totalPropiedades'] ?? 0}', subtitle: 'total'),
          _StatCard(title: 'Ocupadas', value: '${data['ocupadas'] ?? 0}', subtitle: 'alquiladas'),
          _StatCard(title: 'Disponibles', value: '${data['disponibles'] ?? 0}', subtitle: 'libres'),
          _StatCard(title: 'Pagos pendientes', value: '${data['pagosPendientes'] ?? 0}', subtitle: 'por revisar'),
          _StatCard(title: 'Pagos realizados', value: '${data['pagosRealizados'] ?? 0}', subtitle: 'este mes'),
          _StatCard(title: 'Inquilinos', value: '${data['inquilinos'] ?? 0}', subtitle: 'activos'),
        ];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            itemCount: stats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (context, index) => stats[index],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: AppTypography.labelMedium),
          const SizedBox(height: 10),
          Text(value, style: AppTypography.displayMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
