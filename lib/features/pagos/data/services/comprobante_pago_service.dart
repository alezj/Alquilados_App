import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/comprobante_pago.dart';

class ComprobantePagoService {
  Future<Uint8List> generatePdfBytes(ComprobantePagoData data) async {
    final pdf = pw.Document();

    final logoBytes = await rootBundle.load('assets/app_icon.png');
    final logo = pw.MemoryImage(
      logoBytes.buffer.asUint8List(),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(
                        logo,
                        width: 40,
                        height: 40,
                        fit: pw.BoxFit.contain,
                      ),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RECIBO DE PAGO',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue,
                            ),
                          ),
                          pw.Text(
                            'Recibo #${data.numeroRecibo}',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'FECHA:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        data.fecha,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'NÚMERO:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        data.numeroRecibo,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: PdfColors.blue,
                      width: 2,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // ── Información del Cliente ─────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INFORMACIÓN DEL CLIENTE',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'NOMBRE:',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                              pw.Text(
                                data.inquilinoNombre,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'TELÉFONO:',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                              pw.Text(
                                data.telefono,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'DIRECCIÓN:',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                              pw.Text(
                                data.direccion,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // ── Tabla de Descripción y Total ────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DESCRIPCIÓN',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      data.descripcionDetallada,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      data.montoFormateado,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // ── Resumen de Totales ──────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Subtotal',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Text(
                            data.subtotalFormateado,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Retraso',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Text(
                            data.retasoFormateado,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Text(
                            'TOTAL',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Text(
                            data.totalFormateado,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              // ── Mensaje de agradecimiento ───────────────────────
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    '¡Gracias por su pago!',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Comprobante de pago de alquiler',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> shareComprobante(ComprobantePagoData data) async {
    final bytes = await generatePdfBytes(data);
    await Printing.sharePdf(bytes: bytes, filename: data.fileName);
  }
}
