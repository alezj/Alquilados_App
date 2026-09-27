class Propiedad {
  const Propiedad({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.estado,
    required this.precioMensual,
    required this.notas,
    this.syncState = 'pending',
    this.syncedAt,
  });

  final int id;
  final String nombre;
  final String direccion;
  final int estado;
  final double precioMensual;
  final String notas;
  final String syncState;
  final String? syncedAt;
}
