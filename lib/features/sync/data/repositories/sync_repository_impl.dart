import '../../domain/entities/sync_status.dart';
import '../datasources/local_database_service.dart';

abstract interface class SyncRepository {
  Future<SyncStatus> syncNow();
}

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl(this._databaseService);

  final LocalDatabaseService _databaseService;

  @override
  Future<SyncStatus> syncNow() async {
    final db = await _databaseService.database;
    final pendingProperties = await _databaseService.getPendingRows('propiedades');
    final pendingInquilinos = await _databaseService.getPendingRows('inquilinos');
    final pendingPagos = await _databaseService.getPendingRows('pagos');

    final total = pendingProperties.length + pendingInquilinos.length + pendingPagos.length;

    if (total == 0) {
      return const SyncStatus(
        isRunning: false,
        message: 'Todo está sincronizado.',
        lastUpdatedAt: null,
      );
    }

    for (final row in pendingProperties) {
      await _databaseService.logSync(
        'propiedades',
        'sync',
        'success',
        'Fila ${row['id']} marcada como sincronizada localmente.',
      );
      await _databaseService.markSynced('propiedades', row['id'] as int);
    }

    for (final row in pendingInquilinos) {
      await _databaseService.logSync(
        'inquilinos',
        'sync',
        'success',
        'Fila ${row['id']} marcada como sincronizada localmente.',
      );
      await _databaseService.markSynced('inquilinos', row['id'] as int);
    }

    for (final row in pendingPagos) {
      await _databaseService.logSync(
        'pagos',
        'sync',
        'success',
        'Fila ${row['id']} marcada como sincronizada localmente.',
      );
      await _databaseService.markSynced('pagos', row['id'] as int);
    }

    return SyncStatus(
      isRunning: false,
      message: 'Se sincronizaron $total registros locales.',
      lastUpdatedAt: DateTime.now(),
    );
  }
}
