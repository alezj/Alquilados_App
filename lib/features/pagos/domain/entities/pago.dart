class Pago {
  const Pago({
    required this.id,
    required this.idInquilino,
    required this.inquilinoNombre,
    required this.fechaPago,
    required this.monto,
    this.estado = 'pendiente',
    this.syncState = 'pending',
    this.syncedAt,
    this.crmRevision,
    this.periodo,
  });
  final int id;
  final String idInquilino;
  final String inquilinoNombre;
  final String fechaPago;
  final double monto;
  final String estado;
  final String syncState;
  final String? syncedAt;
  final int? crmRevision;
  final String? periodo;

  String get estadoNormalizado => switch (estado.trim().toLowerCase()) {
    'pagado' || 'paid' || 'completado' || 'completada' => 'pagado',
    'pendiente' || 'pending' => 'pendiente',
    'vencido' || 'atrasado' || 'overdue' || 'mora' => 'vencido',
    final valor => valor,
  };

  DateTime? get fechaCalendario {
    final value = fechaPago.trim();
    if (value.length < 10) return null;
    final day = value.substring(0, 10);
    final date = DateTime.tryParse(day);
    if (date == null || date.toIso8601String().substring(0, 10) != day) {
      return null;
    }
    return DateTime.utc(date.year, date.month, date.day);
  }

  bool get porCobrar =>
      const {'pendiente', 'vencido'}.contains(estadoNormalizado);

  bool estaVencido(DateTime hoy) {
    final fecha = fechaCalendario;
    return estadoNormalizado == 'vencido' ||
        (porCobrar && fecha != null && fecha.isBefore(hoy));
  }

  bool venceEnSieteDias(DateTime hoy) {
    final fecha = fechaCalendario;
    return porCobrar &&
        !estaVencido(hoy) &&
        fecha != null &&
        !fecha.isAfter(hoy.add(const Duration(days: 7)));
  }
}
