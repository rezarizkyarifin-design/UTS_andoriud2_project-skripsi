import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = PeminjamanService.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Peminjaman')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Lihat riwayat peminjaman dokumen yang sedang berlangsung dan yang sudah selesai.',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.history, size: 56, color: Colors.blueGrey),
                            SizedBox(height: 12),
                            Text('Belum ada data peminjaman.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return item(history[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget item(Peminjaman peminjaman) {
    final warna = peminjaman.status == 'Dipinjam' ? Colors.orange : Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: warna,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 16,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    peminjaman.nama,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    peminjaman.status,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('No. Hak: ${peminjaman.noHak}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Kecamatan: ${peminjaman.kecamatan}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Kelurahan: ${peminjaman.kelurahan}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Tgl. Pinjam: ${peminjaman.tanggalPinjamFormatted}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Tgl. Kembali: ${peminjaman.tanggalKembaliFormatted}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
