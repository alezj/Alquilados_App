class Pago {
  const Pago({
    required this.id,
    required this.idInquilino,
    required this.fechaPago,
    required this.monto,
  });
  final int id;
  final String idInquilino;
  final String fechaPago;
  final double monto;
}
