class Inquilino {
  const Inquilino({
    required this.id,
    required this.nombreApellido,
    required this.correo,
    required this.fechaInicioContrato,
    required this.fechaPagos,
    this.syncState = 'pending',
    this.syncedAt,
  });

  final int id;
  final String nombreApellido;
  final String? correo;
  final String fechaInicioContrato;
  final int fechaPagos;
  final String syncState;
  final String? syncedAt;
}
