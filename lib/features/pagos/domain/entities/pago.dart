class Pago {
  const Pago({
    required this.id,
    required this.idInquilino,
    required this.fechaPago,
    required this.monto,
    this.estado = 'pendiente',
    this.syncState = 'pending',
    this.syncedAt,
  });
  final int id;
  final String idInquilino;
  final String fechaPago;
  final double monto;
  final String estado;
  final String syncState;
  final String? syncedAt;
}
