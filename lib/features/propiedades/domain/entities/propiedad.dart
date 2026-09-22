class Propiedad {
  const Propiedad({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.estado,
    required this.precioMensual,
    required this.notas,
  });

  final int id;
  final String nombre;
  final String direccion;
  final int estado;
  final double precioMensual;
  final String notas;
}
