import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:projeck_skripsi/screens/peminjaman/form_page.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
    );
  });

  Widget wrap() => const MaterialApp(home: FormPage());

  group('FormPage — initial state', () {
    testWidgets('renders the three document-type chips', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('Buku Tanah'), findsOneWidget);
      expect(find.text('Surat Ukur'), findsOneWidget);
      expect(find.text('Warkah'), findsOneWidget);
    });

    testWidgets('hides detail sections until a type is picked', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('Identitas Peminjam'), findsOneWidget);
      expect(find.text('Detail Objek Arsip'), findsNothing);
      expect(find.text('Keperluan & Waktu'), findsNothing);
      expect(find.text('Simpan Data'), findsNothing);
    });
  });

  group('FormPage — per document type', () {
    testWidgets('Buku Tanah reveals Kecamatan + Kelurahan + Jenis Hak', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Buku Tanah'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Objek Arsip'), findsOneWidget);
      expect(find.text('Kecamatan'), findsOneWidget);
      expect(find.text('Kelurahan'), findsOneWidget);
      expect(find.text('Jenis Hak'), findsOneWidget);
    });

    testWidgets('Surat Ukur reveals Jenis Surat Ukur dropdown', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Surat Ukur'));
      await tester.pumpAndSettle();

      expect(find.text('Jenis Surat Ukur'), findsOneWidget);
      // No. & Tahun only appears after SU/GS is chosen.
      expect(find.textContaining('No. & Tahun'), findsNothing);
    });

    testWidgets('Warkah reveals Jenis Warkah + No. 208 + Tahun', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Warkah'));
      await tester.pumpAndSettle();

      expect(find.text('Jenis Warkah'), findsOneWidget);
      expect(find.text('No. 208'), findsOneWidget);
      expect(find.text('Tahun'), findsOneWidget);
    });
  });

  group('FormPage — save validation', () {
    testWidgets('empty form shows the completeness error', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Buku Tanah'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Data'));
      await tester.pump();

      expect(
        find.text('Lengkapi semua kolom sebelum menyimpan.'),
        findsOneWidget,
      );
    });
  });
}
