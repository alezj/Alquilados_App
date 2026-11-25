import 'dart:convert';

import 'package:sqflite/sqflite.dart';

typedef CrmChange = ({
  String resource,
  int remoteId,
  int revision,
  Map<String, Object?>? values,
});

class CrmSyncStore {
  static const resources = ['propiedades', 'inquilinos', 'alquileres', 'pagos'];

  static Future<void> createSchema(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS crm_sync_records (
      resource TEXT NOT NULL,
      remote_id INTEGER NOT NULL,
      revision INTEGER NOT NULL,
      payload TEXT,
      local_id INTEGER,
      needs_apply INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (resource, remote_id)
    )
  ''');

  Future<int> cursor(Database db) async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT MAX(revision) FROM crm_sync_records'),
      ) ??
      0;

  /// Production uses a scoped snapshot as its source. Persist only
  /// changed payloads so polling does not refresh timestamps or reapply rows.
  Future<({int applied, int pending, Map<int, int> localByRemote})>
  applyProductionSnapshot(
    Database db,
    String resource,
    Map<int, Map<String, Object?>> snapshot,
  ) {
    return db.transaction((txn) async {
      final previous = {
        for (final row in await txn.query(
          'crm_sync_records',
          where: 'resource = ?',
          whereArgs: [resource],
        ))
          row['remote_id'] as int: row['payload'] as String?,
      };
      var revision =
          Sqflite.firstIntValue(
            await txn.rawQuery('SELECT MAX(revision) FROM crm_sync_records'),
          ) ??
          0;
      for (final entry in snapshot.entries) {
        final payload = jsonEncode(entry.value);
        if (previous[entry.key] == payload) continue;
        await _stage(txn, resource, entry.key, ++revision, payload);
      }
      final applied = await _applyResource(
        txn,
        resource,
        deleted: false,
        authorizedIds: snapshot.keys.toSet(),
        productionRentals: resource == 'alquileres',
      );
      final bindings = await txn.rawQuery(
        '''
        SELECT r.remote_id, r.needs_apply, t.id AS local_id
        FROM crm_sync_records r LEFT JOIN $resource t ON t.id = r.local_id
        WHERE r.resource = ?
      ''',
        [resource],
      );
      return (
        applied: applied,
        pending: bindings
            .where(
              (row) =>
                  snapshot.containsKey(row['remote_id']) &&
                  row['needs_apply'] == 1,
            )
            .length,
        localByRemote: {
          for (final row in bindings)
            if (row['local_id'] != null &&
                snapshot.containsKey(row['remote_id']))
              row['remote_id'] as int: row['local_id'] as int,
        },
      );
    });
  }

  Future<({int applied, int pending})> apply(
    Database db,
    List<CrmChange> changes,
  ) {
    return db.transaction((txn) async {
      for (final change in changes) {
        await _stage(
          txn,
          change.resource,
          change.remoteId,
          change.revision,
          change.values == null ? null : jsonEncode(change.values),
        );
      }

      var applied = 0;
      for (final resource in resources) {
        applied += await _applyResource(txn, resource, deleted: false);
      }
      for (final resource in resources.reversed) {
        applied += await _applyResource(txn, resource, deleted: true);
      }
      final pending = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM crm_sync_records WHERE needs_apply = 1',
        ),
      )!;
      return (applied: applied, pending: pending);
    });
  }

  Future<void> _stage(
    Transaction txn,
    String resource,
    int remoteId,
    int revision,
    String? payload,
  ) async {
    await txn.rawInsert(
      '''
      INSERT INTO crm_sync_records(resource, remote_id, revision, payload)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(resource, remote_id) DO UPDATE SET
        revision = excluded.revision, payload = excluded.payload, needs_apply = 1
      WHERE excluded.revision > crm_sync_records.revision
      ''',
      [resource, remoteId, revision, payload],
    );
  }

  Future<int> _applyResource(
    Transaction txn,
    String resource, {
    required bool deleted,
    Set<int>? authorizedIds,
    bool productionRentals = false,
  }) async {
    final changes = await txn.query(
      'crm_sync_records',
      where:
          'resource = ? AND needs_apply = 1 AND payload IS ${deleted ? 'NULL' : 'NOT NULL'}',
      whereArgs: [resource],
      orderBy: 'revision',
    );
    var applied = 0;
    for (final change in changes) {
      final remoteId = change['remote_id']! as int;
      if (authorizedIds != null && !authorizedIds.contains(remoteId)) continue;
      var localId = change['local_id'] as int?;
      final current = await _localRow(txn, resource, localId ?? remoteId);
      if (deleted) {
        if (localId != null && current != null) {
          if (_locallyEdited(current) ||
              await _isReferenced(txn, resource, localId)) {
            continue;
          }
          applied += await txn.delete(
            resource,
            where: 'id = ?',
            whereArgs: [localId],
          );
        }
        localId = null;
      } else {
        final values = Map<String, Object?>.from(
          jsonDecode(change['payload']! as String) as Map,
        );
        if (localId != null && (current == null || _locallyEdited(current))) {
          continue;
        }
        if (!productionRentals &&
            !await _resolveReferences(txn, resource, values)) {
          continue;
        }
        values.putIfAbsent(
          'synced_at',
          () => DateTime.now().toUtc().toIso8601String(),
        );
        if (localId == null &&
            current != null &&
            current['Origen'] == values['Origen'] &&
            current['usuario'] == values['usuario'] &&
            values['created_at'] != null &&
            current['created_at'] == values['created_at']) {
          if (_locallyEdited(current)) continue;
          localId = remoteId;
        }
        if (localId != null) {
          applied += await txn.update(
            resource,
            values,
            where: 'id = ?',
            whereArgs: [localId],
          );
        } else {
          // Keep collisions outside IDs used by legacy sync and local inserts.
          final collisionId = productionRentals && current != null
              ? Sqflite.firstIntValue(
                  await txn.rawQuery(
                    'SELECT MIN(id, 0) - 1 FROM alquileres ORDER BY id LIMIT 1',
                  ),
                )
              : null;
          localId = await txn.insert(resource, {
            ...values,
            if (current == null) 'id': remoteId,
            if (collisionId != null) 'id': collisionId,
          });
          applied++;
        }
      }
      await txn.update(
        'crm_sync_records',
        {'local_id': localId, 'needs_apply': 0},
        where: 'resource = ? AND remote_id = ?',
        whereArgs: [resource, remoteId],
      );
    }
    return applied;
  }

  bool _locallyEdited(Map<String, Object?> row) =>
      row['sync_state'] != 'synced';

  Future<Map<String, Object?>?> _localRow(
    Transaction txn,
    String resource,
    int id,
  ) async {
    final rows = await txn.query(
      resource,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.firstOrNull;
  }

  Future<bool> _resolveReferences(
    Transaction txn,
    String resource,
    Map<String, Object?> values,
  ) async {
    final references = switch (resource) {
      'alquileres' => const {
        'propiedad_id': 'propiedades',
        'inquilino_id': 'inquilinos',
      },
      'pagos' => const {
        'id_inquilino': 'inquilinos',
        'id_alquiler': 'alquileres',
      },
      _ => const <String, String>{},
    };
    for (final reference in references.entries) {
      final remoteId = int.tryParse(values[reference.key]?.toString() ?? '');
      if (remoteId == null || remoteId <= 0) continue;
      final mapped = Sqflite.firstIntValue(
        await txn.rawQuery(
          '''
        SELECT t.id FROM crm_sync_records r JOIN ${reference.value} t ON t.id = r.local_id
        WHERE r.resource = ? AND r.remote_id = ?
        ''',
          [reference.value, remoteId],
        ),
      );
      if (mapped == null) return false;
      values[reference.key] = mapped;
    }
    if (resource == 'pagos') values['alquiler_id'] = values['id_alquiler'];
    return true;
  }

  Future<bool> _isReferenced(Transaction txn, String resource, int id) async {
    final references = switch (resource) {
      'propiedades' => const [
        ('alquileres', 'propiedad_id'),
        ('mantenimientos', 'propiedad_id'),
      ],
      'inquilinos' => const [
        ('alquileres', 'inquilino_id'),
        ('pagos', 'id_inquilino'),
      ],
      'alquileres' => const [
        ('pagos', 'id_alquiler'),
        ('pagos', 'alquiler_id'),
      ],
      _ => const <(String, String)>[],
    };
    for (final (table, column) in references) {
      final children = await txn.query(
        table,
        columns: ['id'],
        where: '$column = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (children.isNotEmpty) return true;
    }
    return false;
  }
}
