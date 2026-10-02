class Alquiler {
  const Alquiler({
    required this.id,
    required this.propiedadId,
    required this.inquilinoId,
    required this.fechaInicio,
    this.fechaFin,
    required this.importe,
    required this.estado,
    this.propiedadNombre,
    this.inquilinoNombre,
  });

  final int id;
  final int propiedadId;
  final int inquilinoId;
  final String fechaInicio;
  final String? fechaFin;
  final double importe;
  final String estado;
  final String? propiedadNombre;
  final String? inquilinoNombre;

  static Alquiler fromMap(Map<String, dynamic> map) {
    return Alquiler(
      id: (map['id'] as num?)?.toInt() ?? 0,
      propiedadId: (map['propiedad_id'] as num?)?.toInt() ?? 0,
      inquilinoId: (map['inquilino_id'] as num?)?.toInt() ?? 0,
      fechaInicio: (map['fecha_inicio'] ?? '').toString(),
      fechaFin: map['fecha_fin']?.toString(),
      importe: _parseDouble(map['importe']),
      estado: (map['estado'] ?? 'Pendiente').toString(),
      propiedadNombre: map['propiedad_nombre']?.toString(),
      inquilinoNombre: map['inquilino_nombre']?.toString(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}
