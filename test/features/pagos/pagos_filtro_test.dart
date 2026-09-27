import 'package:flutter_test/flutter_test.dart';

import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';

// ── Lógica de filtrado extraída para ser testeada en aislamiento ──────────────

List<Pago> filtrarPagos(
  List<Pago> pagos, {
  String? estado, // 'pendiente', 'pagado', 'vencido' o null para todos
  String? yearMonth, // 'YYYY-MM' o null
  String busqueda = '',
}) {
  var resultado = pagos;

  if (estado != null) {
    resultado = resultado.where((p) => p.estado == estado).toList();
  }

  if (yearMonth != null && yearMonth.isNotEmpty) {
    resultado =
        resultado.where((p) => p.fechaPago.startsWith(yearMonth)).toList();
  }

  if (busqueda.isNotEmpty) {
    final q = busqueda.toLowerCase();
    resultado = resultado
        .where(
          (p) =>
              p.idInquilino.toLowerCase().contains(q) ||
              p.monto.toString().contains(q) ||
              p.estado.toLowerCase().contains(q),
        )
        .toList();
  }

  return resultado;
}

// ── Dataset de prueba ─────────────────────────────────────────────────────────

const _pagos = [
  Pago(id: 1, idInquilino: '1', fechaPago: '2026-09-15', monto: 1500, estado: 'pagado'),
  Pago(id: 2, idInquilino: '2', fechaPago: '2026-09-20', monto: 800, estado: 'pendiente'),
  Pago(id: 3, idInquilino: '1', fechaPago: '2026-08-15', monto: 1500, estado: 'pagado'),
  Pago(id: 4, idInquilino: '3', fechaPago: '2026-07-10', monto: 600, estado: 'vencido'),
  Pago(id: 5, idInquilino: '2', fechaPago: '2026-09-01', monto: 2000, estado: 'pendiente'),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('filtrarPagos — sin filtros devuelve todos', () {
    test('lista completa sin filtros', () {
      final resultado = filtrarPagos(_pagos);
      expect(resultado.length, 5);
    });
  });

  group('filtrarPagos — por estado', () {
    test('filtra pagados', () {
      final resultado = filtrarPagos(_pagos, estado: 'pagado');
      expect(resultado.length, 2);
      expect(resultado.every((p) => p.estado == 'pagado'), isTrue);
    });

    test('filtra pendientes', () {
      final resultado = filtrarPagos(_pagos, estado: 'pendiente');
      expect(resultado.length, 2);
      expect(resultado.every((p) => p.estado == 'pendiente'), isTrue);
    });

    test('filtra vencidos', () {
      final resultado = filtrarPagos(_pagos, estado: 'vencido');
      expect(resultado.length, 1);
      expect(resultado.first.id, 4);
    });

    test('estado inexistente devuelve lista vacía', () {
      final resultado = filtrarPagos(_pagos, estado: 'cancelado');
      expect(resultado, isEmpty);
    });
  });

  group('filtrarPagos — por mes (yearMonth)', () {
    test('filtra pagos de septiembre 2026', () {
      final resultado = filtrarPagos(_pagos, yearMonth: '2026-09');
      expect(resultado.length, 3);
    });

    test('filtra pagos de agosto 2026', () {
      final resultado = filtrarPagos(_pagos, yearMonth: '2026-08');
      expect(resultado.length, 1);
      expect(resultado.first.id, 3);
    });

    test('mes sin pagos devuelve lista vacía', () {
      final resultado = filtrarPagos(_pagos, yearMonth: '2025-01');
      expect(resultado, isEmpty);
    });
  });

  group('filtrarPagos — por búsqueda libre', () {
    test('busca por inquilino ID parcial', () {
      final resultado = filtrarPagos(_pagos, busqueda: '2');
      // idInquilino '2' coincide, monto '2000' también contiene '2'
      expect(resultado, isNotEmpty);
    });

    test('busca por estado como texto', () {
      final resultado = filtrarPagos(_pagos, busqueda: 'venc');
      expect(resultado.length, 1);
      expect(resultado.first.estado, 'vencido');
    });

    test('búsqueda vacía no filtra nada', () {
      final resultado = filtrarPagos(_pagos, busqueda: '');
      expect(resultado.length, 5);
    });

    test('búsqueda sin coincidencia devuelve vacío', () {
      final resultado = filtrarPagos(_pagos, busqueda: 'xxxxxx');
      expect(resultado, isEmpty);
    });
  });

  group('filtrarPagos — combinación de filtros', () {
    test('estado pendiente + mes 2026-09', () {
      final resultado = filtrarPagos(
        _pagos,
        estado: 'pendiente',
        yearMonth: '2026-09',
      );
      expect(resultado.length, 2);
      expect(resultado.every((p) => p.estado == 'pendiente'), isTrue);
      expect(resultado.every((p) => p.fechaPago.startsWith('2026-09')),
          isTrue);
    });

    test('estado pagado + busqueda inquilino 1', () {
      final resultado = filtrarPagos(
        _pagos,
        estado: 'pagado',
        busqueda: 'INQ',
      );
      // 'INQ' no coincide con '1' ni '2' → lista vacía
      expect(resultado, isEmpty);
    });

    test('combinación sin resultados', () {
      final resultado = filtrarPagos(
        _pagos,
        estado: 'vencido',
        yearMonth: '2026-09',
      );
      expect(resultado, isEmpty);
    });
  });
}
