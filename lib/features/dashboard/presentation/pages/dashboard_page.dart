import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../app_shell.dart';
import '../../../pagos/presentation/providers/pagos_provider.dart';
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
            icon: Icons.apartment_rounded,
            color: const Color(0xFF6C63FF),
            route: AppRoutes.propiedades,
          ),
          _StatCard(
            title: 'Ocupadas',
            value: '${data['ocupadas'] ?? 0}',
            subtitle: 'alquiladas',
            icon: Icons.lock_rounded,
            color: const Color(0xFFE53935),
            route: AppRoutes.propiedades,
          ),
          _StatCard(
            title: 'Disponibles',
            value: '${data['disponibles'] ?? 0}',
            subtitle: 'libres',
            icon: Icons.lock_open_rounded,
            color: const Color(0xFF43A047),
            route: AppRoutes.propiedades,
          ),
          _StatCard(
            title: 'Alquileres',
            value: '${data['alquileresActivos'] ?? 0}',
            subtitle: 'activos',
            icon: Icons.home_work_rounded,
            color: const Color(0xFF1E88E5),
            onTap: () =>
                ref.read(appShellTabProvider.notifier).goToAlquileres(),
          ),
          _StatCard(
            title: 'Pagos pendientes',
            value: '${data['pagosPendientes'] ?? 0}',
            subtitle: 'por revisar',
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFF4511E),
            onTap: () {
              ref.read(appShellTabProvider.notifier).goToPagos();
              ref
                  .read(pagosFiltroProvider.notifier)
                  .setEstado(FiltroEstadoPago.pendiente);
            },
          ),
          _StatCard(
            title: 'Inquilinos',
            value: '${data['inquilinos'] ?? 0}',
            subtitle: 'activos',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF00897B),
            route: AppRoutes.inquilinos,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const DashboardQuickActions(),
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
    required this.icon,
    required this.color,
    this.route,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? route;
  final VoidCallback? onTap;


@override
Widget build(BuildContext context) {
  return AppCard(
    onTap: onTap ?? (route != null ? () => context.push(route!) : null),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono y valor en la misma fila
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  value,
                  style: AppTypography.displayMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Título
          Text(
            title,
            style: AppTypography.labelMedium,
          ),

          // Subtítulo
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
}

class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    const rentalsTitle = 'Alquileres';
    const paymentsTitle = 'Pagos';
    const actionGap = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - actionGap) / 2;
        final stacked = [rentalsTitle, paymentsTitle].any(
          (title) => cardWidth < _ActionCard.horizontalWidth(context, title),
        );

        return Row(
          spacing: actionGap,
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.home_work_rounded,
                color: const Color(0xFF1E88E5),
                title: rentalsTitle,
                subtitle: isMobile
                    ? null
                    : 'Ver contratos activos, pendientes y finalizados.',
                stacked: stacked,
                onTap: () =>
                    ref.read(appShellTabProvider.notifier).goToAlquileres(),
              ),
            ),
            Expanded(
              child: _ActionCard(
                icon: Icons.payment_rounded,
                color: const Color(0xFF43A047),
                title: paymentsTitle,
                subtitle: isMobile ? null : 'Crear pago',
                stacked: stacked,
                onTap: () {
                  ref.read(appShellTabProvider.notifier).goToPagos();
                  ref.read(openCreatePagoSheetProvider.notifier).trigger();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.stacked,
    required this.onTap,
    this.subtitle,
  });

  static const _padding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const _iconPadding = EdgeInsets.all(8);
  static const _iconSize = 20.0;
  static const _horizontalGap = 16.0;

  final IconData icon;
  final Color color;
  final String title;
  final bool stacked;
  final VoidCallback onTap;
  final String? subtitle;

  static double horizontalWidth(BuildContext context, String title) {
    final titleWidth = TextPainter.computeWidth(
      text: TextSpan(text: title, style: Theme.of(context).textTheme.bodyLarge),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );

    return _padding.horizontal +
        _iconPadding.horizontal +
        2 * _iconSize +
        2 * _horizontalGap +
        titleWidth.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final iconBadge = Container(
      padding: _iconPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: _iconSize, color: color),
    );
    final textTheme = Theme.of(context).textTheme;
    final labels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.bodyLarge,
          textAlign: stacked ? TextAlign.center : TextAlign.start,
        ),
        if (subtitle case final subtitle?)
          Text(
            subtitle,
            style: textTheme.bodyMedium,
            textAlign: stacked ? TextAlign.center : TextAlign.start,
          ),
      ],
    );

    return AppCard(
      padding: _padding,
      onTap: onTap,
      child: stacked
          ? Column(children: [iconBadge, const SizedBox(height: 8), labels])
          : Row(
              spacing: _horizontalGap,
              children: [
                iconBadge,
                Expanded(child: labels),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: color,
                  size: _iconSize,
                ),
              ],
            ),
    );
  }
}
