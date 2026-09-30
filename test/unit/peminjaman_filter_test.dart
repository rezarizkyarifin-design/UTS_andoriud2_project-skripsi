import 'package:flutter_test/flutter_test.dart';
import 'package:projeck_skripsi/models/peminjaman.dart';
import 'package:projeck_skripsi/screens/services/peminjaman_service.dart';

void main() {
  Peminjaman sample({
    required String nama,
    String kecamatan = 'Cilegon',
    String kelurahan = 'Bagendung',
    String noHak = '11111',
    String jenisHak = 'Hak Milik',
    String jenisDokumen = 'Buku Tanah',
    String status = 'Dipinjam',
    String? jenisWarkah,
    String? no208,
    String? su,
  }) {
    return Peminjaman(
      id: 'x',
      nama: nama,
      seksi: 'Seksi Tata Usaha',
      kecamatan: kecamatan,
      kelurahan: kelurahan,
      jenisHak: jenisHak,
      noHak: noHak,
      keperluan: 'Verifikasi',
      tanggalPinjam: DateTime(2025, 1, 1),
      tanggalKembali: DateTime(2025, 1, 8),
      status: status,
      jenisDokumen: jenisDokumen,
      jenisWarkah: jenisWarkah,
      no208: no208,
      su: su,
    );
  }

  group('PeminjamanService.debugFilter', () {
    final data = [
      sample(nama: 'Budi Santoso', noHak: '11111'),
      sample(
        nama: 'Siti Rahma',
        noHak: '22222',
        jenisDokumen: 'Surat Ukur',
        jenisHak: 'Hak Guna Bangunan',
        status: 'Kembali',
        su: '45/2020',
      ),
      sample(
        nama: 'Ahmad Yani',
        noHak: '-',
        jenisDokumen: 'Warkah',
        jenisHak: '-',
        jenisWarkah: 'PBT',
        no208: '999',
      ),
    ];

    test('matches by borrower name (case-insensitive)', () {
      final r = PeminjamanService.debugFilter(source: data, query: 'BUDI');
      expect(r, hasLength(1));
      expect(r.first.nama, 'Budi Santoso');
    });

    test('matches by noHak', () {
      final r = PeminjamanService.debugFilter(source: data, query: '22222');
      expect(r.single.nama, 'Siti Rahma');
    });

    test('matches Surat Ukur by SU number', () {
      final r = PeminjamanService.debugFilter(source: data, query: '45/2020');
      expect(r.single.jenisDokumen, 'Surat Ukur');
    });

    test('matches Warkah by No. 208', () {
      final r = PeminjamanService.debugFilter(source: data, query: '999');
      expect(r.single.jenisWarkah, 'PBT');
    });

    test('filters by jenisDokumen', () {
      final r = PeminjamanService.debugFilter(
        source: data,
        jenisDokumen: 'Warkah',
      );
      expect(r, hasLength(1));
    });

    test('filters by status', () {
      final r = PeminjamanService.debugFilter(source: data, status: 'Kembali');
      expect(r.single.nama, 'Siti Rahma');
    });

    test('no query, no filter returns everything', () {
      expect(PeminjamanService.debugFilter(source: data), hasLength(3));
    });

    test('query matching nothing returns empty', () {
      expect(
        PeminjamanService.debugFilter(source: data, query: 'zzzzz'),
        isEmpty,
      );
    });
  });
}
