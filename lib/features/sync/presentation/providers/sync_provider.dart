import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../alquileres/presentation/providers/alquileres_provider.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../inquilinos/presentation/providers/inquilinos_provider.dart';
import '../../../pagos/presentation/providers/pagos_provider.dart';
import '../../../propiedades/presentation/providers/propiedades_provider.dart';
import '../../data/datasources/local_database_service.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/entities/sync_status.dart';

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepositoryImpl(
    ref.watch(localDatabaseServiceProvider),
    ref.watch(apiClientProvider),
  );
});

final syncStateProvider =
    StateNotifierProvider<SyncController, AsyncValue<SyncStatus>>((ref) {
      return SyncController(
        ref.watch(syncRepositoryProvider),
        ref.watch(secureStorageProvider),
        onCrmChanges: () {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(propiedadesProvider);
          ref.invalidate(propiedadDetalleProvider);
          ref.invalidate(inquilinosProvider);
          ref.invalidate(inquilinoDetalleProvider);
          ref.invalidate(pagosDeInquilinoProvider);
          ref.invalidate(alquileresProvider);
          ref.invalidate(pagosProvider);
          ref.invalidate(pagoDetalleProvider);
        },
      );
    });

class SyncController extends StateNotifier<AsyncValue<SyncStatus>> {
  SyncController(this._repository, this._storage, {required this.onCrmChanges})
    : super(
        const AsyncValue.data(
          SyncStatus(
            isRunning: false,
            message: 'Sincronización lista.',
            lastUpdatedAt: null,
          ),
        ),
      );

  final SyncRepository _repository;
  final SecureStorageService _storage;
  final void Function() onCrmChanges;
  Future<void>? _active;

  Future<void> syncFromCrm() async {
    if (AppConfig.backend == BackendEnvironment.test) await syncNow();
  }

  Future<void> refreshAfterCrmWrite() async {
    await _active;
    if (mounted) await syncFromCrm();
  }

  Future<void> syncNow() =>
      _active ??= _run().whenComplete(() => _active = null);

  Future<void> _run() async {
    try {
      final isPilot = AppConfig.backend == BackendEnvironment.test;
      String? tenant;
      String? companyId;
      if (isPilot) {
        final session = await _storage.getSessionContext();
        if (session?['environment'] != BackendEnvironment.test.name ||
            !await _storage.hasToken()) {
          return;
        }
        tenant = session?['tenant'] as String?;
        companyId = session?['companyId'] as String?;
        if (tenant == null) return;
      }
      if (!mounted) return;
      state = const AsyncValue.loading();
      final result = tenant == null
          ? await _repository.syncNow()
          : await _repository.pullCrm(tenant: tenant, companyId: companyId);
      if (mounted) {
        if (result.localChanges > 0) onCrmChanges();
        state = AsyncValue.data(result);
      }
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
    }
  }
}
