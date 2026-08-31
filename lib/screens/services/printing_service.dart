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

  static Future<void> printBarcodeLabel({
    // BUG FIX (.08.2026 notes): jenisHak/noHak only ever mean something
    // for Buku Tanah (and, incidentally, Surat Ukur, which also carries
    // a noHak) — Warkah always has noHak == '-', so the printed label
    // used to show a blank dash where its actual identifying number (No.
    // 208) should be. identifierLabel/identifierValue are computed by
    // the caller per jenisDokumen (see barcode_page.dart), and
    // secondaryDetail carries the type-specific extra the notes asked
    // for (SU/GS for Surat Ukur, Tahun for Warkah).
    required String identifierLabel,
    required String identifierValue,
    String? secondaryDetail,
    required String nama,
    required String seksi,
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
                  data: identifierValue,
                  width: 150,
                  height: 150,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                identifierLabel,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                identifierValue,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (secondaryDetail != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  secondaryDetail,
                  style: const pw.TextStyle(fontSize: 7.5),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Text(
                // Same fix as barcode_page.dart's on-screen card — Warkah
                // has no kelurahan (always '-'), so printing it
                // unconditionally produced a dangling "Nama - -" on the
                // physical label. Seksi is always present regardless of
                // document type, so it fills that gap.
                kelurahan != '-'
                    ? '$nama - Seksi $seksi - $kelurahan'
                    : '$nama - Seksi $seksi',
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
      name: 'Barcode_$identifierValue',
    );
  }

  static Future<void> shareAsImage({
    required GlobalKey boundaryKey,
    required String identifierValue,
  }) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List bytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/barcode_$identifierValue.png');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Barcode peminjaman dokumen $identifierValue');
  }
}
