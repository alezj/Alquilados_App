import 'package:intl/intl.dart';

import '../../../inquilinos/domain/entities/inquilino.dart';
import 'pago.dart';

class ComprobantePagoData {
  const ComprobantePagoData({
    required this.idPago,
    required this.numeroRecibo,
    required this.fecha,
    required this.inquilinoNombre,
    required this.telefono,
    required this.direccion,
    required this.monto,
    required this.estado,
    required this.descripcionDetallada,
    this.subtotal = 0.0,
    this.retaso = 0.0,
    this.isFiscal = false,
  });

  final int idPago;
  final String numeroRecibo;
  final String fecha;
  final String inquilinoNombre;
  final String telefono;
  final String direccion;
  final double monto;
  final String estado;
  final String descripcionDetallada;
  final double subtotal;
  final double retaso;
  final bool isFiscal;

  factory ComprobantePagoData.fromPayment(Pago pago, [Inquilino? inquilino]) {
    final parsedDate = DateTime.tryParse(pago.fechaPago);
    final fechaFormateada = parsedDate == null
        ? pago.fechaPago
        : DateFormat('dd/MM/yyyy').format(parsedDate);

    return ComprobantePagoData(
      idPago: pago.id,
      numeroRecibo: pago.id.toString(),
      fecha: fechaFormateada,
      inquilinoNombre: inquilino?.nombreApellido ?? 'Inquilino no disponible',
      telefono: inquilino?.correo ?? '-',
      direccion: '-',
      monto: pago.monto,
      estado: pago.estado,
      descripcionDetallada: 'Pago de propiedad: - · Transferencia · Banreservas · Ref. 123456',
      subtotal: pago.monto,
      retaso: 0.0,
      isFiscal: false,
    );
  }

  String get titulo => isFiscal ? 'FACTURA' : 'RECIBO DE PAGO';

  String get montoFormateado => NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(monto);

  String get subtotalFormateado => NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(subtotal);

  String get retasoFormateado => NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(retaso);

  String get totalFormateado => NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(monto);

  String get fileName => 'recibo_pago_${numeroRecibo}_${DateTime.now().millisecondsSinceEpoch}.pdf';
}
