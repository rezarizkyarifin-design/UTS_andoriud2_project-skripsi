import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';

class ReturnPage extends StatefulWidget {
  const ReturnPage({super.key});

  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  final _noHakController = TextEditingController();
  Peminjaman? _peminjaman;

  @override
  void dispose() {
    _noHakController.dispose();
    super.dispose();
  }

  void _cariPeminjaman() {
    final noHak = _noHakController.text.trim();
    if (noHak.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor hak.')),
      );
      return;
    }

    final peminjaman = PeminjamanService.getAll().firstWhere(
      (p) => p.noHak == noHak && p.status == 'Dipinjam',
      orElse: () => Peminjaman(
        nama: '',
        seksi: '',
        kecamatan: '',
        kelurahan: '',
        jenisHak: '',
        noHak: '',
        keperluan: '',
        tanggalPinjam: DateTime.now(),
        tanggalKembali: DateTime.now(),
      ),
    );

    if (peminjaman.noHak.isEmpty) {
      setState(() {
        _peminjaman = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peminjaman tidak ditemukan atau sudah dikembalikan.')),
      );
    } else {
      setState(() {
        _peminjaman = peminjaman;
      });
    }
  }

  void _kembalikan() {
    if (_peminjaman != null) {
      PeminjamanService.kembalikan(_peminjaman!.noHak);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumen berhasil dikembalikan.')),
      );
      setState(() {
        _peminjaman = null;
        _noHakController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengembalian Dokumen')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextFormField(
                controller: _noHakController,
                decoration: InputDecoration(
                  labelText: 'Nomor Hak',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _cariPeminjaman,
                  child: const Text('Cari Peminjaman', style: TextStyle(fontSize: 16)),
                ),
              ),
              if (_peminjaman != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nama: ${_peminjaman!.nama}'),
                      Text('Seksi: ${_peminjaman!.seksi}'),
                      Text('Kecamatan: ${_peminjaman!.kecamatan}'),
                      Text('Kelurahan: ${_peminjaman!.kelurahan}'),
                      Text('Jenis Hak: ${_peminjaman!.jenisHak}'),
                      Text('No. Hak: ${_peminjaman!.noHak}'),
                      Text('Keperluan: ${_peminjaman!.keperluan}'),
                      Text('Tanggal Pinjam: ${_peminjaman!.tanggalPinjamFormatted}'),
                      Text('Tanggal Kembali: ${_peminjaman!.tanggalKembaliFormatted}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: Colors.green,
                    ),
                    onPressed: _kembalikan,
                    child: const Text('Kembalikan Dokumen', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}