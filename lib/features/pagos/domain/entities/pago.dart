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
}
