import '../../domain/entities/propiedad.dart';

class PropiedadModel extends Propiedad {
  const PropiedadModel({
    required super.id,
    required super.nombre,
    required super.direccion,
    required super.estado,
    required super.precioMensual,
    required super.notas,
  });

  factory PropiedadModel.fromJson(Map<String, dynamic> json) {
    return PropiedadModel(
      id: _asInt(json['id']),
      nombre: json['nombre']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      estado: _asInt(json['estado']),
      precioMensual: _asDouble(json['precioMensual']),
      notas: json['notas']?.toString() ?? '',
    );
  }

  static int _asInt(dynamic value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };

  static double _asDouble(dynamic value) => switch (value) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value) ?? 0,
    _ => 0,
  };
}
