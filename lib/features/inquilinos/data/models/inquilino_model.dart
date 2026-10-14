import '../../domain/entities/inquilino.dart';

class InquilinoModel extends Inquilino {
  const InquilinoModel({
    required super.id,
    required super.nombreApellido,
    super.correo,
    super.fechaInicioContrato,
    super.fechaPagos,
  });

  factory InquilinoModel.fromJson(Map<String, dynamic> json) => InquilinoModel(
    id: _asInt(json['id']),
    nombreApellido: json['nombreApellido']?.toString() ?? '',
    correo: (json['correo'] ?? json['email'])?.toString(),
    fechaInicioContrato: json['fechaInicioContrato']?.toString(),
    fechaPagos: _asNullableInt(json['fechaPagos']),
  );

  static int _asInt(dynamic value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };

  static int? _asNullableInt(dynamic value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };
}
