import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../sync/data/datasources/local_database_service.dart';

class PaymentCatalog {
  const PaymentCatalog({required this.methods, required this.banks});

  final Map<String, bool> methods;
  final List<String> banks;

  factory PaymentCatalog.fromJson(Map<String, dynamic> json) => PaymentCatalog(
    methods: Map<String, bool>.from(json['methods'] as Map),
    banks: List<String>.from(json['banks'] as List),
  );

  Map<String, Object> toJson() => {'methods': methods, 'banks': banks};
}

class PaymentCatalogRepository {
  const PaymentCatalogRepository(this._database, this._storage, this._api);

  final LocalDatabaseService _database;
  final SecureStorageService _storage;
  final ApiClient _api;

  Future<PaymentCatalog> load() async {
    final environment = AppConfig.backend;
    final session = await _storage.getSessionContext();
    final company = session?['companyId'] as String?;
    final tenant = session?['tenant'] as String?;
    if (company == null ||
        session?['environment'] != environment.name ||
        tenant != _database.tenantKey ||
        !await _storage.hasToken()) {
      throw const UnauthorizedException();
    }
    final db = await _database.database;
    final filters = {'company_id': 'eq.$company', 'order': 'nombre.asc,id.asc'};
    try {
      final (methods, banks) = await (
        _api.get<List<dynamic>>(
          'formas_pago',
          queryParameters: {
            ...filters,
            'select': 'nombre,requiere_banco',
            'activa': 'eq.true',
          },
        ),
        _api.get<List<dynamic>>(
          'bancos',
          queryParameters: {
            ...filters,
            'select': 'nombre',
            'activo': 'eq.true',
          },
        ),
      ).wait;
      await _checkScope(tenant, company, environment, db);
      final catalog = PaymentCatalog(
        methods: {
          for (final row in methods.data!)
            row['nombre'] as String: row['requiere_banco'] == true,
        },
        banks: {for (final row in banks.data!) row['nombre'] as String}
            .toList(),
      );
      await db.insert('payment_catalog', {
        'company_id': company,
        'payload': jsonEncode(catalog.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return catalog;
    } on ParallelWaitError catch (error) {
      final (methodError, bankError) =
          error.errors as (AsyncError?, AsyncError?);
      final errors = [methodError?.error, bankError?.error].nonNulls;
      if (errors.any((e) => e is! NetworkException && e is! TimeoutException)) {
        throw errors.firstWhere(
          (e) => e is! NetworkException && e is! TimeoutException,
        );
      }
      await _checkScope(tenant, company, environment, db);
      final cached = await db.query(
        'payment_catalog',
        columns: ['payload'],
        where: 'company_id = ?',
        whereArgs: [company],
      );
      if (cached.isEmpty) throw const NetworkException();
      return PaymentCatalog.fromJson(
        jsonDecode(cached.single['payload'] as String) as Map<String, dynamic>,
      );
    }
  }

  Future<void> _checkScope(
    String? tenant,
    String company,
    BackendEnvironment environment,
    Database db,
  ) async {
    final session = await _storage.getSessionContext();
    if (!db.isOpen ||
        session?['companyId'] != company ||
        tenant != _database.tenantKey ||
        environment != AppConfig.backend) {
      throw const UnauthorizedException();
    }
  }
}
