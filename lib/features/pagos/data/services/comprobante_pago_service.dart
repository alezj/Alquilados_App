import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/comprobante_pago.dart';

class ComprobantePagoService {
  Future<Uint8List> generatePdfBytes(ComprobantePagoData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                data.titulo,
                style: const pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Documento generado localmente para referencia del pago.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 16),
              ...data.rows.map(
                (row) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 110,
                        child: pw.Text(
                          row['label'] ?? '',
                          style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(row['value'] ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      data.montoFormateado,
                      style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Nota: este comprobante es no fiscal y se genera con los datos locales de la app.',
                style: const pw.TextStyle(fontSize: 10),
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
