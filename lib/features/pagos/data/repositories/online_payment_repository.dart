import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';

/// Transport for a confirmed payment write. A future offline queue can supply
/// its own persisted operation ID and submit the same command to this API.
class OnlinePaymentRepository {
  const OnlinePaymentRepository(this._api);

  final ApiClient _api;

  Future<int> submit({
    required String companyId,
    required String operationId,
    required Map<String, Object?> command,
  }) async {
    final response = await _api.post<int>(
      'rpc/mobile_write_payment',
      data: {
        'p_company_id': companyId,
        'p_operation_id': operationId,
        'p_command': command,
      },
    );
    final id = response.data;
    if (id == null) throw const ServerException();
    return id;
  }
}

/// Remembers the identity of an unconfirmed request for a manual retry. This
/// table does not create payments or send requests when connectivity returns.
class PaymentRequestStore {
  Future<int> submit(
    Database db,
    OnlinePaymentRepository repository,
    String companyId,
    Map<String, Object?> command,
  ) async {
    final request = jsonEncode([companyId, command]);
    final operationId = await db.transaction((txn) async {
      final existing = await txn.query(
        'online_payment_requests',
        columns: ['operation_id'],
        where: 'request = ?',
        whereArgs: [request],
      );
      if (existing.isNotEmpty) return existing.single['operation_id'] as String;
      final id = _newOperationId();
      await txn.insert('online_payment_requests', {
        'request': request,
        'operation_id': id,
      });
      return id;
    });

    Future<void> forgetAttempt() async {
      // A session switch may already have closed the cache after the server
      // response. Retaining the attempt is safe because the server deduplicates it.
      if (!db.isOpen) return;
      await db.delete(
        'online_payment_requests',
        where: 'request = ? AND operation_id = ?',
        whereArgs: [request, operationId],
      );
    }

    try {
      final id = await repository.submit(
        companyId: companyId,
        operationId: operationId,
        command: command,
      );
      try {
        await forgetAttempt();
      } on DatabaseException {
        // The acknowledged server write remains valid even if cleanup fails.
      }
      return id;
    } on AppException catch (error) {
      if (error is BadRequestException ||
          error is NotFoundException ||
          error is ConflictException ||
          error is ForbiddenException) {
        try {
          await forgetAttempt();
        } on DatabaseException {
          // Leave the request available for inspection if the cache is unavailable.
        }
      }
      rethrow;
    }
  }

  String _newOperationId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
