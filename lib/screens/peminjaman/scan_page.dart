import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/peminjaman_service.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isScanning = false;
  bool _hasDetected = false;
  bool _torchOn = false;

  static const Color _accentGreen = Color(0xFF52B788);
  static const Color _primaryGreen = Color(0xFF1B4332);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── CAMERA DETECT ───
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

  // ─── PILIH DARI GALERI ───
  Future<void> _pilihDariGaleri() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image == null) return;

    setState(() => _hasDetected = false);
    final bool detected = await _controller.analyzeImage(image.path);

    if (!detected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tidak ada barcode/QR terdeteksi pada gambar.'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ─── PROSES HASIL SCAN ───
  void _prosesHasilScan(String noHak) {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text('Tidak Ditemukan'),
            content: Text(
              'Tidak ada peminjaman aktif dengan No. Hak "$noHak".',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _hasDetected = false);
                  if (_isScanning) _controller.start();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
                if (_isScanning) _controller.start();
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                PeminjamanService.kembalikan(noHak);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Dokumen No. Hak $noHak berhasil dikembalikan.',
                    ),
                    backgroundColor: _accentGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                Navigator.pop(context); // Balik ke halaman sebelumnya
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

  void _toggleScan() {
    setState(() {
      _isScanning = !_isScanning;
      _hasDetected = false;
    });
    if (_isScanning) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  // ─── CORNER BRACKET OVERLAY ───
  Widget _corner({
    required Alignment alignment,
    required bool top,
    required bool left,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: _accentGreen, width: 4)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: _accentGreen, width: 4)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: _accentGreen, width: 4)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: _accentGreen, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(10) : Radius.zero,
            topRight: top && !left ? const Radius.circular(10) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(10) : Radius.zero,
            bottomRight: !top && !left
                ? const Radius.circular(10)
                : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _scanFrame() {
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          children: [
            _corner(alignment: Alignment.topLeft, top: true, left: true),
            _corner(alignment: Alignment.topRight, top: true, left: false),
            _corner(alignment: Alignment.bottomLeft, top: false, left: true),
            _corner(alignment: Alignment.bottomRight, top: false, left: false),
          ],
        ),
      ),
    );
  }

  // ─── CUSTOM FLOATING APP BAR ───
  Widget _floatingAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            const Text(
              'Scan QR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            _circleIconButton(
              icon: _torchOn ? Icons.flash_on : Icons.flash_off,
              onTap: () {
                _controller.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
              highlighted: _torchOn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: highlighted ? _accentGreen : Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview / placeholder
          Positioned.fill(
            child: _isScanning
                ? MobileScanner(controller: _controller, onDetect: _onDetect)
                : Container(
                    color: const Color(0xFF121212),
                    child: const Center(
                      child: Icon(
                        Icons.qr_code_scanner,
                        size: 90,
                        color: Colors.white24,
                      ),
                    ),
                  ),
          ),

          // ── Dim overlay supaya teks & bracket lebih kontras
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withOpacity(0.15)),
            ),
          ),

          // ── Corner bracket + instruksi (hanya saat aktif)
          if (_isScanning) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 220,
              child: _scanFrame(),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: 250,
              child: Column(
                children: const [
                  Text(
                    'Arahkan kamera ke barcode dokumen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pastikan pencahayaan cukup dan barcode terlihat jelas di dalam kotak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ] else
            const Positioned(
              left: 32,
              right: 32,
              bottom: 250,
              child: Text(
                'Kamera belum aktif. Tekan tombol di bawah untuk mulai scan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),

          // ── Custom floating app bar
          Positioned(top: 0, left: 0, right: 0, child: _floatingAppBar()),

          // ── Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Mendukung QR Code & Barcode BPN',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Mulai/Stop Scan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleScan,
                        icon: Icon(
                          _isScanning
                              ? Icons.stop_circle_outlined
                              : Icons.qr_code_scanner,
                          color: Colors.white,
                        ),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _isScanning ? 'Stop Scan' : 'Mulai Scan',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning
                              ? const Color(0xFFB3261E)
                              : _accentGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Pilih dari Galeri
                    TextButton.icon(
                      onPressed: _pilihDariGaleri,
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        'Pilih dari Galeri',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
