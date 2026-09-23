import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/datasources/local_database_service.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/entities/sync_status.dart';

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepositoryImpl(ref.watch(localDatabaseServiceProvider));
});

final syncStateProvider = StateNotifierProvider<SyncController, AsyncValue<SyncStatus>>((ref) {
  return SyncController(ref.read(syncRepositoryProvider));
});

class SyncController extends StateNotifier<AsyncValue<SyncStatus>> {
  SyncController(this._repository) : super(const AsyncValue.data(SyncStatus(
          isRunning: false,
          message: 'Sincronización lista.',
          lastUpdatedAt: null,
        )));

  final SyncRepository _repository;

  Future<void> syncNow() async {
    state = const AsyncValue.loading();

    try {
      final result = await _repository.syncNow();
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
