import 'package:intl/intl.dart';

import '../../../inquilinos/domain/entities/inquilino.dart';
import 'pago.dart';

class ComprobantePagoData {
  const ComprobantePagoData({
    required this.idPago,
    required this.inquilinoNombre,
    required this.fechaPago,
    required this.monto,
    required this.estado,
    required this.descripcion,
    this.isFiscal = false,
  });

  final int idPago;
  final String inquilinoNombre;
  final String fechaPago;
  final double monto;
  final String estado;
  final String descripcion;
  final bool isFiscal;

  factory ComprobantePagoData.fromPayment(Pago pago, [Inquilino? inquilino]) {
    final parsedDate = DateTime.tryParse(pago.fechaPago);
    final fechaFormateada = parsedDate == null
        ? pago.fechaPago
        : DateFormat('dd/MM/yyyy').format(parsedDate);

    return ComprobantePagoData(
      idPago: pago.id,
      inquilinoNombre: inquilino?.nombreApellido ?? 'Inquilino no disponible',
      fechaPago: fechaFormateada,
      monto: pago.monto,
      estado: pago.estado,
      descripcion: 'Pago de alquiler',
      isFiscal: false,
    );
  }

  String get titulo => isFiscal ? 'FACTURA' : 'COMPROBANTE NO FISCAL';

  String get montoFormateado => NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(monto);

  String get fileName => 'comprobante_pago_${idPago}_${DateTime.now().millisecondsSinceEpoch}.pdf';

  List<Map<String, String>> get rows => [
        {'label': 'Número', 'value': '#$idPago'},
        {'label': 'Inquilino', 'value': inquilinoNombre},
        {'label': 'Fecha', 'value': fechaPago},
        {'label': 'Estado', 'value': estado},
        {'label': 'Concepto', 'value': descripcion},
      ];
}
