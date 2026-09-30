import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:projeck_skripsi/models/peminjaman.dart';
import 'package:projeck_skripsi/screens/peminjaman/return_page.dart';
import 'package:projeck_skripsi/screens/services/peminjaman_service.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
    );
  });

  setUp(() => PeminjamanService.debugClearCache());

  Widget wrap() => const MaterialApp(home: ReturnPage());

  Peminjaman activeLoan({
    String id = 'loan-1',
    String nama = 'Budi',
    String noHak = '12345',
    String jenisDokumen = 'Buku Tanah',
    DateTime? dueDate,
  }) {
    return Peminjaman(
      id: id,
      nama: nama,
      seksi: 'Seksi Tata Usaha',
      kecamatan: 'Cilegon',
      kelurahan: 'Bagendung',
      jenisHak: 'Hak Milik',
      noHak: noHak,
      keperluan: 'Verifikasi',
      tanggalPinjam: DateTime(2025, 1, 1),
      tanggalKembali: dueDate ?? DateTime.now().add(const Duration(days: 7)),
      status: 'Dipinjam',
      jenisDokumen: jenisDokumen,
    );
  }

  group('ReturnPage — empty state', () {
    testWidgets('shows the empty-state card when the cache is empty', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Pinjaman Aktif'), findsOneWidget);
      expect(
        find.textContaining('Semua dokumen sudah dikembalikan'),
        findsOneWidget,
      );
      expect(find.text('Catat Peminjaman'), findsOneWidget);
    });

    testWidgets('renders header, search bar, and bottom nav', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Pengembalian'), findsOneWidget);
      expect(find.text('Pinjaman Aktif'), findsOneWidget);
      expect(find.text('Masukkan Nomor Hak...'), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Arsip'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
    });
  });

  group('ReturnPage — with data', () {
    testWidgets('renders one card per active loan', (tester) async {
      PeminjamanService.debugSeedCache([
        activeLoan(id: 'a', nama: 'Budi'),
        activeLoan(id: 'b', nama: 'Siti', noHak: '67890'),
      ]);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Siti'), findsOneWidget);
      expect(find.text('Tidak Ada Pinjaman Aktif'), findsNothing);
    });

    testWidgets('shows a "Terlambat" badge on an overdue loan', (tester) async {
      final overdue = DateTime.now().subtract(const Duration(days: 3));
      PeminjamanService.debugSeedCache([
        activeLoan(id: 'a', nama: 'Budi', dueDate: overdue),
      ]);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('Terlambat'), findsWidgets);
    });

    testWidgets('search filters the visible list', (tester) async {
      PeminjamanService.debugSeedCache([
        activeLoan(id: 'a', nama: 'Budi'),
        activeLoan(id: 'b', nama: 'Siti', noHak: '99999'),
      ]);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Siti');
      await tester.pumpAndSettle();

      expect(find.text('Siti'), findsOneWidget);
      expect(find.text('Budi'), findsNothing);
    });

    testWidgets('long-press enters selection mode', (tester) async {
      PeminjamanService.debugSeedCache([activeLoan(id: 'a', nama: 'Budi')]);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Budi'));
      await tester.pumpAndSettle();

      // "Pilih" toggles to "Batal" and the bulk-action bar appears.
      expect(find.text('Batal'), findsWidgets);
      expect(find.textContaining('dokumen dipilih'), findsOneWidget);
    });
  });
}
