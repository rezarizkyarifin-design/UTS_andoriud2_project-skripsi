import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/peminjaman_service.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = false;
  bool _hasDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return; // Cegah deteksi ganda

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _hasDetected = true);
    _controller.stop();

    _prosesHasilScan(rawValue);
  }

  void _prosesHasilScan(String noHak) {
    // Cari peminjaman berdasarkan noHak yang di-scan
    final semua = PeminjamanService.getAll();
    final peminjaman = semua
        .where((p) => p.noHak == noHak && p.status == 'Dipinjam')
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        if (peminjaman.isEmpty) {
          return AlertDialog(
            title: const Text('Tidak Ditemukan'),
            content: Text(
              'Tidak ada peminjaman aktif dengan No. Hak "$noHak".',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _hasDetected = false);
                  _controller.start();
                },
                child: const Text('Scan Ulang'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          );
        }

        final p = peminjaman.first;
        return AlertDialog(
          title: const Text('Dokumen Ditemukan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama: ${p.nama}'),
              const SizedBox(height: 4),
              Text('Seksi: ${p.seksi}'),
              const SizedBox(height: 4),
              Text('No. Hak: ${p.noHak}'),
              const SizedBox(height: 4),
              Text('Tgl. Kembali: ${p.tanggalKembaliFormatted}'),
              const SizedBox(height: 12),
              const Text(
                'Kembalikan dokumen ini?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _hasDetected = false);
                _controller.start();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                PeminjamanService.kembalikan(noHak);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Dokumen No. Hak $noHak berhasil dikembalikan.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context); // Balik ke home
              },
              child: const Text(
                'Kembalikan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Dokumen'),
        actions: [
          // Toggle flash
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Lampu Flash',
          ),
          // Ganti kamera depan/belakang
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Ganti Kamera',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Area scanner
            Expanded(
              flex: 3,
              child: _isScanning
                  ? Stack(
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                        ),
                        // Overlay panduan scan
                        Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'Arahkan kamera ke QR Code dokumen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: Colors.black12,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 80,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Kamera tidak aktif',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
            ),

            // Panel bawah
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _isScanning
                          ? 'Scanner aktif — arahkan ke QR Code'
                          : 'Tekan tombol di bawah untuk mulai scan',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isScanning = !_isScanning;
                            _hasDetected = false;
                          });
                          if (_isScanning) {
                            _controller.start();
                          } else {
                            _controller.stop();
                          }
                        },
                        icon: Icon(_isScanning ? Icons.stop : Icons.camera_alt),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _isScanning ? 'Stop Scan' : 'Mulai Scan',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning
                              ? Colors.red
                              : Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
