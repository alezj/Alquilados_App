import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sync/data/datasources/local_database_service.dart';

final dashboardSummaryProvider = FutureProvider<Map<String, int>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();
  return database.getDashboardSummary();
});

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dashboardSummaryProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardSummaryProvider);

    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('No pudimos cargar el resumen.')),
      data: (data) {
        final stats = [
          _StatCard(
            title: 'Propiedades',
            value: '${data['totalPropiedades'] ?? 0}',
            subtitle: 'total',
            route: AppRoutes.propiedades,
          ),
          _StatCard(
            title: 'Ocupadas',
            value: '${data['ocupadas'] ?? 0}',
            subtitle: 'alquiladas',
            route: AppRoutes.propiedades,
          ),
          _StatCard(
            title: 'Disponibles',
            value: '${data['disponibles'] ?? 0}',
            subtitle: 'libres',
            route: AppRoutes.propiedades,
          ),
          _StatCard(
            title: 'Alquileres',
            value: '${data['alquileresActivos'] ?? 0}',
            subtitle: 'activos',
            route: AppRoutes.alquileres,
          ),
          _StatCard(
            title: 'Pagos pendientes',
            value: '${data['pagosPendientes'] ?? 0}',
            subtitle: 'por revisar',
            route: AppRoutes.pagos,
          ),
          _StatCard(
            title: 'Inquilinos',
            value: '${data['inquilinos'] ?? 0}',
            subtitle: 'activos',
            route: AppRoutes.inquilinos,
          ),
        ];

        final isMobile = MediaQuery.sizeOf(context).width < 600;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      onTap: () => context.push(AppRoutes.alquileres),
                      child: ListTile(
                        leading: const Icon(Icons.home_work_rounded),
                        title: const Text('Alquileres'),
                        subtitle: isMobile
                            ? null
                            : const Text(
                                'Ver contratos activos, pendientes y finalizados.',
                              ),
                        trailing: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: AppCard(
                      onTap: () => context.push(
                        '${AppRoutes.pagos}?openCreate=true',
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.payment_rounded),
                        title: const Text('Pagos'),
                        subtitle: isMobile
                            ? null
                            : const Text('Crear pago'),
                        trailing: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
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
              ),
            ],
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
    this.route,
  });

  final String title;
  final String value;
  final String subtitle;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: route != null ? () => context.push(route!) : null,
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
