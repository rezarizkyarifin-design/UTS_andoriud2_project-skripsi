import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PrintingService {
  PrintingService._();

  /// Opens the native Print Document dialog with a small label-sized PDF
  /// (QR + nomor hak + tanggal) sized to be printed and stuck onto the
  /// physical buku tanah.
  static Future<void> printBarcodeLabel({
    required String noHak,
    required String nama,
    required String kelurahan,
    required String tanggalPinjam,
    required String tanggalKembali,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(226, 340, marginAll: 14),
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'KANTOR PERTANAHAN CILEGON',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: bc.Barcode.qrCode(),
                  data: noHak,
                  width: 150,
                  height: 150,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                noHak,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$nama - $kelurahan',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Pinjam: $tanggalPinjam',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.Text(
                'Kembali: $tanggalKembali',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Barcode_$noHak',
    );
  }

  static Future<void> shareAsImage({
    required GlobalKey boundaryKey,
    required String noHak,
  }) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List bytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/barcode_$noHak.png');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Barcode peminjaman dokumen No. Hak $noHak');
  }
}
