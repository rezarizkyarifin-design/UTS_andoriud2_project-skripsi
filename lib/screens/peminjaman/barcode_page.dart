import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../services/printing_service.dart';

class BarcodePage extends StatefulWidget {
  const BarcodePage({super.key});

  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage> {
  final GlobalKey _qrBoundaryKey = GlobalKey();

  bool _isPrinting = false;
  bool _isSavingImage = false;

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label $value disalin ke papan klip'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cetak({
    required String identifierLabel,
    required String identifierValue,
    String? secondaryDetail,
    required String nama,
    required String seksi,
    required String kelurahan,
    required String tanggalPinjam,
    required String tanggalKembali,
  }) async {
    setState(() => _isPrinting = true);
    try {
      await PrintingService.printBarcodeLabel(
        identifierLabel: identifierLabel,
        identifierValue: identifierValue,
        secondaryDetail: secondaryDetail,
        nama: nama,
        seksi: seksi,
        kelurahan: kelurahan,
        tanggalPinjam: tanggalPinjam,
        tanggalKembali: tanggalKembali,
      );
    } catch (e) {
      if (mounted) _showError('Gagal membuka dialog cetak: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _bagikanGambar(String identifierValue) async {
    setState(() => _isSavingImage = true);
    try {
      await PrintingService.shareAsImage(
        boundaryKey: _qrBoundaryKey,
        identifierValue: identifierValue,
      );
    } catch (e) {
      if (mounted) _showError('Gagal menyimpan gambar: $e');
    } finally {
      if (mounted) setState(() => _isSavingImage = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppTheme.accentGreen),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: Colors.black38),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
    final noHak = args?['noHak'] ?? '-';
    final nama = args?['nama'] ?? '-';
    final seksi = args?['seksi'] ?? '-';
    final kelurahan = args?['kelurahan'] ?? '-';
    final jenisHak = args?['jenisHak'] ?? '-';
    final jenisDokumen = args?['jenisDokumen'] ?? 'Buku Tanah';
    final tanggalPinjam = args?['tanggalPinjam'] ?? '-';
    final tanggalKembali = args?['tanggalKembali'] ?? '-';

    // ── Surat Ukur–specific ──
    final jenisSuratUkur = args?['jenisSuratUkur'] ?? '';
    final noTahunSuratUkur = args?['noTahunSuratUkur'] ?? '';
    final su = args?['su'] ?? '';
    final gs = args?['gs'] ?? '';

    // ── Warkah–specific ──
    final jenisWarkah = args?['jenisWarkah'] ?? '';
    final no208 = args?['no208'] ?? '';
    final tahunWarkah = args?['tahunWarkah'] ?? '';

    // ── Compute type-aware identifiers ──
    //
    // Buku Tanah  → label = jenisHak (e.g. "Hak Milik"), value = noHak
    //                secondary = kelurahan if present
    // Surat Ukur  → label = "$jenisSuratUkur $noTahunSuratUkur",
    //                value = SU number (su) or GS number (gs),
    //                secondary = "No. SU: $su / GS: $gs"
    // Warkah      → label = jenisWarkah, value = no208 (the real
    //                identifier; noHak is always '-' for Warkah),
    //                secondary = "Tahun $tahunWarkah"
    final String identifierLabel;
    final String identifierValue; // shown big on the card + in QR
    final String qrData; // encoded into the QR code
    final String? secondaryDetail;

    switch (jenisDokumen) {
      case 'Surat Ukur':
        // Prefer SU number; fall back to GS number if SU is empty.
        final suNumber = su.isNotEmpty ? su : gs;
        identifierLabel =
            '${jenisSuratUkur.isNotEmpty ? jenisSuratUkur : 'Surat Ukur'}'
            '${noTahunSuratUkur.isNotEmpty ? ' – $noTahunSuratUkur' : ''}';
        identifierValue = suNumber.isNotEmpty ? suNumber : noHak;
        qrData = suNumber.isNotEmpty ? suNumber : noHak;
        secondaryDetail = [
          if (su.isNotEmpty) 'No. SU: $su',
          if (gs.isNotEmpty) 'GS: $gs',
        ].join(' / ');
        break;

      case 'Warkah':
        identifierLabel =
            '${jenisWarkah.isNotEmpty ? jenisWarkah : 'Warkah'}'
            '${tahunWarkah.isNotEmpty ? ' Tahun $tahunWarkah' : ''}';
        identifierValue = no208.isNotEmpty ? no208 : '-';
        qrData = no208.isNotEmpty ? no208 : '-';
        secondaryDetail = tahunWarkah.isNotEmpty ? 'Tahun $tahunWarkah' : null;
        break;

      default: // 'Buku Tanah'
        identifierLabel = jenisHak;
        identifierValue = noHak;
        qrData = noHak;
        secondaryDetail = null;
    }

    // Subtitle line shown below the big identifier on the card:
    // always show "Nama · Seksi X" regardless of type; then append
    // kelurahan only for Buku Tanah (it's always '-' for the others).
    final subtitleLine = kelurahan != '-'
        ? '$nama · Seksi $seksi · $kelurahan'
        : '$nama · Seksi $seksi';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Barcode Pengembalian',
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // ── Success icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppTheme.successGreen,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Peminjaman Berhasil Disimpan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cetak & tempelkan kode QR ini pada buku tanah,\natau tunjukkan saat proses pengembalian.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // ── QR Card (RepaintBoundary supaya bisa di-capture sebagai
              // gambar tanpa ikut menyertakan tombol di bawahnya)
              RepaintBoundary(
                key: _qrBoundaryKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.divider,
                            width: 1.2,
                          ),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 200.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppTheme.primaryGreen,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Identifier label + value box (copy button)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.tag,
                              size: 18,
                              color: AppTheme.accentGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    identifierLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black38,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    identifierValue,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (secondaryDetail != null &&
                                      secondaryDetail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      secondaryDetail,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_rounded,
                                size: 20,
                                color: Colors.black45,
                              ),
                              onPressed: () => _copyToClipboard(
                                identifierLabel,
                                identifierValue,
                              ),
                              splashRadius: 22,
                              tooltip: 'Salin nomor dokumen',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Tanggal Pinjam / Kembali
                      Row(
                        children: [
                          _infoTile(
                            icon: Icons.calendar_month_outlined,
                            label: 'Tanggal Pinjam',
                            value: tanggalPinjam,
                          ),
                          const SizedBox(width: 10),
                          _infoTile(
                            icon: Icons.event_available_outlined,
                            label: 'Batas Kembali',
                            value: tanggalKembali,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Tombol Cetak (native Print Document dialog)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPrinting
                      ? null
                      : () => _cetak(
                          identifierLabel: identifierLabel,
                          identifierValue: identifierValue,
                          secondaryDetail: secondaryDetail,
                          nama: nama,
                          seksi: seksi,
                          kelurahan: kelurahan,
                          tanggalPinjam: tanggalPinjam,
                          tanggalKembali: tanggalKembali,
                        ),
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.print_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                  label: Text(
                    _isPrinting ? 'Menyiapkan...' : 'Cetak Barcode',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Tombol Simpan/Bagikan sebagai Gambar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSavingImage
                      ? null
                      : () => _bagikanGambar(identifierValue),
                  icon: _isSavingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentGreen,
                          ),
                        )
                      : const Icon(
                          Icons.ios_share_rounded,
                          size: 18,
                          color: AppTheme.accentGreen,
                        ),
                  label: Text(
                    _isSavingImage ? 'Menyimpan...' : 'Bagikan sebagai Gambar',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentGreen,
                    side: const BorderSide(color: AppTheme.accentGreen),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Tombol Kembali ke Home
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false,
                  ),
                  icon: const Icon(
                    Icons.home_rounded,
                    size: 18,
                    color: Colors.black54,
                  ),
                  label: const Text(
                    'Kembali ke Beranda',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
