class Alquiler {
  const Alquiler({
    required this.id,
    required this.propiedadId,
    required this.inquilinoId,
    required this.fechaInicio,
    this.fechaFin,
    required this.importe,
    required this.montoPago,
    required this.cantidadDepositos,
    required this.diaPago,
    this.cantidadMeses = 0,
    required this.estado,
    this.propiedadNombre,
    this.inquilinoNombre,
    this.pagosRealizados = 0,
  });

  final int id;
  final int propiedadId;
  final int inquilinoId;
  final String fechaInicio;
  final String? fechaFin;
  final double importe;
  final double montoPago;
  final int cantidadDepositos;
  final int diaPago;
  final int cantidadMeses;
  final String estado;
  final String? propiedadNombre;
  final String? inquilinoNombre;
  final int pagosRealizados;

  /// Cantidad de meses pendientes por pagar (meses acordados menos pagos realizados)
  int get pagosPendientes {
    final pendientes = cantidadMeses - pagosRealizados;
    return pendientes > 0 ? pendientes : 0;
  }

  static Alquiler fromMap(Map<String, dynamic> map) {
    final importe = _parseDouble(map['importe']);
    final montoPago = _parseDouble(map['montoPago'] ?? map['monto_pago'] ?? map['importe']);
    final cantidadDepositos = ((map['cantidadDepositos'] ?? map['cantidad_depositos'] ?? 0) as num?)?.toInt() ?? 0;
    final diaPago = ((map['diaPago'] ?? map['dia_pago'] ?? 1) as num?)?.toInt() ?? 1;
    var cantidadMeses = ((map['cantidadMeses'] ?? map['cantidad_meses'] ?? 0) as num?)?.toInt() ?? 0;
    final pagosRealizados = ((map['pagos_realizados'] ?? map['pagosRealizados'] ?? 0) as num?)?.toInt() ?? 0;

    final fechaInicioStr = (map['fecha_inicio'] ?? '').toString();
    final fechaFinStr = map['fecha_fin']?.toString();

    // Fallback: Si cantidadMeses viene en 0 pero hay fechas, calcularla
    if (cantidadMeses <= 0 && fechaInicioStr.isNotEmpty && fechaFinStr != null && fechaFinStr.isNotEmpty) {
      final inicio = DateTime.tryParse(fechaInicioStr);
      final fin = DateTime.tryParse(fechaFinStr);
      if (inicio != null && fin != null && !fin.isBefore(inicio)) {
        final finAjustado = fin.add(const Duration(days: 1));
        var m = (finAjustado.year - inicio.year) * 12 + (finAjustado.month - inicio.month);
        if (finAjustado.day < inicio.day) m--;
        if (m <= 0 && fin.difference(inicio).inDays >= 25) m = 1;
        if (m > 0) cantidadMeses = m;
      }
    }

    return Alquiler(
      id: (map['id'] as num?)?.toInt() ?? 0,
      propiedadId: (map['propiedad_id'] as num?)?.toInt() ?? 0,
      inquilinoId: (map['inquilino_id'] as num?)?.toInt() ?? 0,
      fechaInicio: fechaInicioStr,
      fechaFin: fechaFinStr,
      importe: importe,
      montoPago: montoPago,
      cantidadDepositos: cantidadDepositos,
      diaPago: diaPago,
      cantidadMeses: cantidadMeses,
      estado: (map['estado'] ?? 'Pendiente').toString(),
      propiedadNombre: map['propiedad_nombre']?.toString(),
      inquilinoNombre: map['inquilino_nombre']?.toString(),
      pagosRealizados: pagosRealizados,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}
