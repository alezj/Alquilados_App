import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:alquilados_app/features/sync/data/datasources/local_database_service.dart';
import 'package:alquilados_app/features/sync/data/repositories/sync_repository_impl.dart';

class MockLocalDatabaseService extends Mock implements LocalDatabaseService {}

void main() {
  late MockLocalDatabaseService mockDbService;
  late SyncRepositoryImpl repository;

  setUp(() {
    mockDbService = MockLocalDatabaseService();
    repository = SyncRepositoryImpl(mockDbService);
  });

  group('SyncRepositoryImpl Tests', () {
    test('syncNow returns synced message when there are no pending rows', () async {
      when(() => mockDbService.getPendingRows(any())).thenAnswer((_) async => []);

      final status = await repository.syncNow();

      expect(status.isRunning, false);
      expect(status.message, 'Todo está sincronizado.');
      expect(status.lastUpdatedAt, isNull);
      verify(() => mockDbService.getPendingRows('propiedades')).called(1);
      verify(() => mockDbService.getPendingRows('inquilinos')).called(1);
      verify(() => mockDbService.getPendingRows('pagos')).called(1);
    });

    test('syncNow marks rows as synced and logs sync when pending rows exist', () async {
      when(() => mockDbService.getPendingRows('propiedades')).thenAnswer(
        (_) async => [
          {'id': 1, 'nombre': 'Prop 1'},
        ],
      );
      when(() => mockDbService.getPendingRows('inquilinos')).thenAnswer((_) async => []);
      when(() => mockDbService.getPendingRows('pagos')).thenAnswer((_) async => []);

      when(
        () => mockDbService.logSync(
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => 1);

      when(() => mockDbService.markSynced(any(), any())).thenAnswer((_) async => 1);

      final status = await repository.syncNow();

      expect(status.isRunning, false);
      expect(status.message, 'Se sincronizaron 1 registros locales.');
      expect(status.lastUpdatedAt, isNotNull);

      verify(() => mockDbService.markSynced('propiedades', 1)).called(1);
      verify(
        () => mockDbService.logSync(
          'propiedades',
          'sync',
          'success',
          'Fila 1 marcada como sincronizada localmente.',
        ),
      ).called(1);
    });
  });
}
