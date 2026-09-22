import '../../domain/entities/pago.dart';

class PagoModel extends Pago {
  const PagoModel({
    required super.id,
    required super.idInquilino,
    required super.fechaPago,
    required super.monto,
  });
  factory PagoModel.fromJson(Map<String, dynamic> json) => PagoModel(
    id: _asInt(json['id']),
    idInquilino: json['idInquilino']?.toString() ?? '',
    fechaPago: json['fechaPago']?.toString() ?? '',
    monto: _asDouble(json['monto']),
  );
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
