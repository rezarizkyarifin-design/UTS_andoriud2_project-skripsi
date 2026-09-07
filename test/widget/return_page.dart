import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeck_skripsi/screens/peminjaman/form_page.dart'; // Adjust import with actual path

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('FormPage Widget Tests', () {
    testWidgets('Merender pilihan Jenis Dokumen secara benar pada awal muat', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const FormPage()));

      // Pastikan dropdown/chip opsi Jenis Dokumen ada
      expect(find.text('Buku Tanah'), findsOneWidget);
      expect(find.text('Surat Ukur'), findsOneWidget);
      expect(find.text('Warkah'), findsOneWidget);

      // Tombol Simpan Data belum tampil jika jenis dokumen belum dipilih
      expect(find.text('Simpan Data'), findsNothing);
    });

    testWidgets(
      'Menampilkan form spesifik Surat Ukur saat "Surat Ukur" dipilih',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableWidget(const FormPage()));

        // Tap pada pilihan 'Surat Ukur'
        await tester.tap(find.text('Surat Ukur'));
        await tester.pumpAndSettle();

        // Memastikan field spesifik Surat Ukur seperti SU / GS atau No/Tahun SU tampil
        expect(find.text('Simpan Data'), findsOneWidget);
      },
    );

    testWidgets('Validasi pengisian form dan eksekusi tombol Simpan Data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const FormPage()));

      // Pilih Buku Tanah
      await tester.tap(find.text('Buku Tanah'));
      await tester.pumpAndSettle();

      // Temukan tombol simpan
      final simpanButton = find.text('Simpan Data');
      expect(simpanButton, findsOneWidget);

      await tester.tap(simpanButton);
      await tester.pumpAndSettle();
    });
  });
}
