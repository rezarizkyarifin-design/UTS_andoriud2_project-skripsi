import '../models/peminjaman.dart';

class PeminjamanService {
  static final List<Peminjaman> _data = [];
  static int _sedangDipinjam = 0;
  static int _telahKembali = 0;

  static List<Peminjaman> getAll() => _data;

  static int getSedangDipinjam() => _sedangDipinjam;

  static int getTelahKembali() => _telahKembali;

  static void tambah(Peminjaman p) {
    _data.add(p);
    _sedangDipinjam++;
  }

  static void kembalikan(String noHak) {
    for (var item in _data) {
      if (item.noHak == noHak && item.status == "Dipinjam") {
        item.status = "Dikembalikan";
        _sedangDipinjam--;
        _telahKembali++;
        break;
      }
    }
  }

  static List<String> getNotifikasi() {
    final now = DateTime.now();
    final notifikasi = <String>[];

    for (var item in _data) {
      if (item.status == "Dipinjam") {
        final daysLeft = item.tanggalKembali.difference(now).inDays;
        if (daysLeft < 0) {
          notifikasi.add('Buku tanah ${item.noHak} sudah melewati batas waktu pengembalian.');
        } else if (daysLeft <= 3) {
          notifikasi.add('Buku tanah ${item.noHak} akan habis waktu peminjamannya dalam $daysLeft hari.');
        }
      }
    }

    return notifikasi;
  }
}
