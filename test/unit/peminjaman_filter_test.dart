import 'package:flutter_test/flutter_test.dart';

// Dummy model matching Peminjaman data structure
class PeminjamanMock {
  final String nama;
  final String kecamatan;
  final String kelurahan;
  final String noHak;
  final String jenisHak;
  final String jenisDokumen;
  final String status;

  PeminjamanMock({
    required this.nama,
    required this.kecamatan,
    required this.kelurahan,
    required this.noHak,
    required this.jenisHak,
    required this.jenisDokumen,
    required this.status,
  });
}

void main() {
  group('Peminjaman Filter Logic Tests', () {
    final mockData = [
      PeminjamanMock(
        nama: 'Budi Santoso',
        kecamatan: 'Cibeunying Kaler',
        kelurahan: 'Cihaur Geulis',
        noHak: '01234',
        jenisHak: 'Hak Milik',
        jenisDokumen: 'Buku Tanah',
        status: 'Dipinjam',
      ),
      PeminjamanMock(
        nama: 'Siti Rahma',
        kecamatan: 'Coblong',
        kelurahan: 'Dago',
        noHak: '56789',
        jenisHak: 'Hak Guna Bangunan',
        jenisDokumen: 'Surat Ukur',
        status: 'Kembali',
      ),
      PeminjamanMock(
        nama: 'Ahmad Yani',
        kecamatan: 'Coblong',
        kelurahan: 'Dago',
        noHak: '99999',
        jenisHak: 'Hak Pakai',
        jenisDokumen: 'Warkah',
        status: 'Dipinjam',
      ),
    ];

    test('Filter berdasarkan pencarian nama atau nomor hak', () {
      final query = 'budi';
      final result = mockData.where((p) {
        final haystack = '${p.nama} ${p.noHak}'.toLowerCase();
        return haystack.contains(query.toLowerCase());
      }).toList();

      expect(result.length, equals(1));
      expect(result.first.nama, equals('Budi Santoso'));
    });

    test(
      'Filter berdasarkan Jenis Dokumen (Buku Tanah / Surat Ukur / Warkah)',
      () {
        final filteredSuratUkur = mockData
            .where((p) => p.jenisDokumen == 'Surat Ukur')
            .toList();
        final filteredWarkah = mockData
            .where((p) => p.jenisDokumen == 'Warkah')
            .toList();

        expect(filteredSuratUkur.length, equals(1));
        expect(filteredSuratUkur.first.noHak, equals('56789'));
        expect(filteredWarkah.length, equals(1));
        expect(filteredWarkah.first.jenisDokumen, equals('Warkah'));
      },
    );

    test('Filter berdasarkan Status (Dipinjam / Kembali)', () {
      final activeLoans = mockData
          .where((p) => p.status == 'Dipinjam')
          .toList();
      final returnedLoans = mockData
          .where((p) => p.status == 'Kembali')
          .toList();

      expect(activeLoans.length, equals(2));
      expect(returnedLoans.length, equals(1));
      expect(returnedLoans.first.nama, equals('Siti Rahma'));
    });
  });
}
