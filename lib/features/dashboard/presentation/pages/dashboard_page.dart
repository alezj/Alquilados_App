import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_error.dart';
import '../../../../core/shared/widgets/app_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../app_shell.dart';
import '../../../pagos/presentation/providers/pagos_provider.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/dashboard_collections.dart';

final dashboardSummaryProvider = FutureProvider<Map<String, int>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();
  return database.getDashboardSummary();
});

final dashboardCollectionsProvider = Provider<AsyncValue<DashboardCollections>>(
  (ref) {
    final today = ref.watch(hoyPagosProvider);
    return ref
        .watch(pagosProvider)
        .whenData(
          (payments) => DashboardCollections.fromPayments(
            today: today,
            payments: payments,
          ),
        );
  },
);

final _currency = NumberFormat.currency(
  locale: 'es_US',
  symbol: 'RD\$',
  decimalDigits: 2,
);

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final collections = ref.watch(dashboardCollectionsProvider);
    final colors = Theme.of(context).colorScheme;

    void openPayments(FiltroEstadoPago filter) {
      ref.read(pagosFiltroProvider.notifier).abrirDesdeInicio(filter);
      ref.read(appShellTabProvider.notifier).goToPagos();
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await Future.wait([
              ref.refresh(dashboardSummaryProvider.future),
              ref.refresh(pagosProvider.future),
            ]);
          } catch (_) {
            // The affected section displays its retry state.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.apartment_rounded, color: colors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Alquilados',
                            style: AppTypography.titleSmall,
                          ),
                        ),
                        collections.maybeWhen(
                          data: (data) => Flexible(
                            child: Text(
                              _monthLabel(data.today),
                              textAlign: TextAlign.end,
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Resumen', style: AppTypography.displayMedium),
                    const SizedBox(height: 14),
                    collections.when(
                      data: (data) => _CollectionsCard(data: data),
                      loading: () => const AppCard(
                        child: AppLoading(message: 'Cargando cobros…'),
                      ),
                      error: (_, _) => AppError(
                        title: 'No pudimos cargar los cobros',
                        message: 'Vuelve a cargar los datos de pagos.',
                        onRetry: () => ref.invalidate(pagosProvider),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const DashboardQuickActions(),
                    const SizedBox(height: 18),
                    if (collections.hasValue) ...[
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Por atender',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            _AlertRow(
                              label: 'Pagos vencidos',
                              count: collections.requireValue.overdue,
                              icon: Icons.error_outline_rounded,
                              urgent: true,
                              onTap: () =>
                                  openPayments(FiltroEstadoPago.vencido),
                            ),
                            const Divider(height: 1),
                            _AlertRow(
                              label: 'Próximos 7 días',
                              count: collections.requireValue.upcoming,
                              icon: Icons.event_outlined,
                              onTap: () =>
                                  openPayments(FiltroEstadoPago.proximos),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    summary.when(
                      data: (data) => AppCard(
                        onTap: () => context.push(AppRoutes.propiedades),
                        child: Row(
                          children: [
                            Icon(
                              Icons.apartment_rounded,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ocupación',
                                    style: AppTypography.titleSmall,
                                  ),
                                  Text(
                                    '${data['ocupadas'] ?? 0} de ${data['totalPropiedades'] ?? 0} propiedades ocupadas',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => AppError(
                        title: 'No pudimos cargar la ocupación',
                        message: 'Vuelve a cargar el resumen de propiedades.',
                        onRetry: () => ref.invalidate(dashboardSummaryProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _CollectionsCard extends StatelessWidget {
  const _CollectionsCard({required this.data});

  final DashboardCollections data;

  @override
  Widget build(BuildContext context) {
    final progress = data.collectionProgress;
    final percent = progress == null ? null : (progress * 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cobrado este mes',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              _currency.format(data.collected),
              style: AppTypography.displayLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 7),
            Text(
              '${_currency.format(data.outstanding)} por cobrar del mes',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
                backgroundColor: Colors.white30,
                semanticsLabel: 'Avance de cobro de los pagos del período',
              ),
              const SizedBox(height: 6),
              Text(
                '$percent % de ${_currency.format(data.expected)} previstos para el mes',
                style: AppTypography.bodySmall.copyWith(color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
    this.urgent = false,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final needsAttention = urgent && count > 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: needsAttention ? colors.error : colors.onSurfaceVariant,
      ),
      title: Text(label, style: AppTypography.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: AppTypography.labelLarge.copyWith(
              color: needsAttention ? colors.error : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key});

  static const _payments = 'Registrar pago';
  static const _rentals = 'Alquileres';
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap) / 2;
        final labelWidth = TextPainter.computeWidth(
          text: const TextSpan(
            text: _payments,
            style: AppTypography.labelLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        );
        final stacked = width < labelWidth.ceilToDouble() + 72;

        return IntrinsicHeight(
          child: Row(
            spacing: _gap,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.payment_rounded,
                  title: _payments,
                  primary: true,
                  stacked: stacked,
                  onTap: () {
                    ref.read(appShellTabProvider.notifier).goToPagos();
                    ref.read(openCreatePagoSheetProvider.notifier).trigger();
                  },
                ),
              ),
              Expanded(
                child: _ActionCard(
                  icon: Icons.home_work_rounded,
                  title: _rentals,
                  stacked: stacked,
                  onTap: () =>
                      ref.read(appShellTabProvider.notifier).goToAlquileres(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.stacked,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final bool stacked;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = primary ? colors.onPrimary : colors.onSurface;
    final badge = Icon(
      icon,
      size: 20,
      color: primary ? foreground : colors.primary,
    );
    final label = Text(
      title,
      textAlign: TextAlign.center,
      style: AppTypography.labelLarge.copyWith(color: foreground),
    );

    return AppCard(
      color: primary ? colors.primary : null,
      borderColor: primary ? Colors.transparent : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      child: stacked
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [badge, const SizedBox(height: 6), label],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                badge,
                Flexible(child: label),
              ],
            ),
    );
  }
}
