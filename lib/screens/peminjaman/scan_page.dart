import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/peminjaman_service.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  // MENTOR FIX: Prevent the camera from auto-starting on page load to stabilize initialization.
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  final ImagePicker _imagePicker = ImagePicker();

  bool _isScanning = false;
  bool _hasDetected = false;
  bool _torchOn = false;

  late final AnimationController _scanLineController;

  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _scanGreen = Color(0xFF52B788);

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  // ─── CAMERA DETECT ───
  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _hasDetected = true);
    _controller.stop(); // Stop feed temporarily while processing

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
              'Tidak ada peminjaman aktif dengan No. Hak "$noHak".\n\nPastikan QR Code yang discan sesuai dengan database.',
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
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: Colors.black54),
                ),
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
                  ),
                );
                Navigator.pop(context); // Return to previous page
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

    // Controller commands are now safely executed because the
    // MobileScanner widget is permanently mounted in the background.
    if (_isScanning) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  // ─── OVERLAYS AND UI HELPERS ───
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
                ? const BorderSide(color: _scanGreen, width: 4)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: _scanGreen, width: 4)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: _scanGreen, width: 4)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: _scanGreen, width: 4)
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

  Widget _scanLine() {
    return AnimatedBuilder(
      animation: _scanLineController,
      builder: (context, child) {
        return Positioned(
          top: 6 + (_scanLineController.value * 228),
          left: 6,
          right: 6,
          child: Container(
            height: 2.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: [
                  _scanGreen.withOpacity(0),
                  _scanGreen,
                  _scanGreen.withOpacity(0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _scanGreen.withOpacity(0.7),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scanFrame() {
    final active = _isScanning && !_hasDetected;
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _corner(alignment: Alignment.topLeft, top: true, left: true),
            _corner(alignment: Alignment.topRight, top: true, left: false),
            _corner(alignment: Alignment.bottomLeft, top: false, left: true),
            _corner(alignment: Alignment.bottomRight, top: false, left: false),
            if (active) _scanLine(),
          ],
        ),
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    double radius = 22,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.32),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _floatingAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: _glassPanel(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isScanning ? _scanGreen : Colors.white38,
                      boxShadow: _isScanning
                          ? [
                              BoxShadow(
                                color: _scanGreen.withOpacity(0.8),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  Text(
                    _isScanning ? 'Memindai...' : 'Scan QR / Barcode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: highlighted ? _scanGreen : Colors.white.withOpacity(0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // MENTOR FIX: MobileScanner is now permanently mounted in the tree.
          // This prevents the hardware race condition that causes freezing.
          Positioned.fill(
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),

          // If NOT scanning, overlay the dark placeholder view to hide the camera feed.
          if (!_isScanning)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D0D0D), Color(0xFF1B1B1B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.qr_code_scanner,
                    size: 90,
                    color: _scanGreen.withOpacity(0.25),
                  ),
                ),
              ),
            ),

          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withOpacity(0.15)),
            ),
          ),

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
                children: [
                  Text(
                    'Arahkan kamera ke barcode dokumen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pastikan pencahayaan cukup dan barcode terlihat jelas di dalam kotak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ] else
            Positioned(
              left: 32,
              right: 32,
              bottom: 250,
              child: _glassPanel(
                child: const Text(
                  'Kamera belum aktif. Tekan tombol di bawah untuk mulai scan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),

          Positioned(top: 0, left: 0, right: 0, child: _floatingAppBar()),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _glassPanel(
                  radius: 26,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.white.withOpacity(0.75),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mendukung QR Code & Barcode BPN',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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
                                : _scanGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
          ),
        ],
      ),
    );
  }
}
