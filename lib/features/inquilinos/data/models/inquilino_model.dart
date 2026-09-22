import '../../domain/entities/inquilino.dart';

class InquilinoModel extends Inquilino {
  const InquilinoModel({
    required super.id,
    required super.nombreApellido,
    required super.correo,
    required super.fechaInicioContrato,
    required super.fechaPagos,
  });

  factory InquilinoModel.fromJson(Map<String, dynamic> json) => InquilinoModel(
    id: _asInt(json['id']),
    nombreApellido: json['nombreApellido']?.toString() ?? '',
    correo: (json['correo'] ?? json['email'])?.toString(),
    fechaInicioContrato: json['fechaInicioContrato']?.toString() ?? '',
    fechaPagos: _asInt(json['fechaPagos']),
  );

  static int _asInt(dynamic value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };
}
