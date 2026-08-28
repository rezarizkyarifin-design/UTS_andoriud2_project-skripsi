import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../services/peminjaman_service.dart';
import '../services/auth_service.dart';
import '../../data/data.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_scan_fab.dart';
import '../../widgets/back_to_home.dart';
import '../../widgets/app_top_bar.dart';
// import '../../widgets/jenis_dokumen_breakdown.dart'; // removed for now, see build()

class ReturnPage extends StatefulWidget {
  const ReturnPage({super.key});

  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

// ─── Item #6 (koreksi): dua state, bukan tiga — lihat penjelasan
// lengkap di history_page.dart, logikanya sama persis di sini. Ringkasnya:
// full    → header gradient + stat + search bar, semua tampil (posisi
//           beneran di paling atas, atau daftarnya kependekan buat
//           discroll sama sekali).
// compact → header gradient disembunyikan, tapi search bar tetap
//           tampil — state default begitu user geser dari paling atas,
//           entah scroll ke atas ATAU ke bawah. (Return Page nggak
//           punya status chips kayak History, jadi compact-nya cuma
//           search bar.) Nggak pernah balik ke "semuanya ilang" lagi.
enum _HeaderVisibility { full, compact }

class _ReturnPageState extends State<ReturnPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? _filterKecamatan;
  String? _filterKelurahan;
  String? _filterJenisHak;
  String? _filterJenisDokumen; // 'Buku Tanah' | 'Surat Ukur' | 'Warkah'

  late List<Peminjaman> _all;
  int _selectedNavIndex = 3;

  bool _isLoading = true;
  String? _loadError;

  // ─── Note item #13: multi-select "Tandai Kembali" ───
  bool _selectionMode = false;
  // Renamed from _selectedNoHak: this feeds straight into
  // PeminjamanService.kembalikanBanyak(ids), which is id-keyed (see the
  // 11.08.2026 comment on PeminjamanService._findActiveById for why —
  // noHak is '-' for every Warkah loan, so it can't tell two active
  // Warkah documents apart). Selecting by noHak here would've silently
  // fed the wrong values into an id-keyed bulk update.
  final Set<String> _selectedIds = {};
  bool _isBulkSaving = false;

  // Item #6: drives the collapsing header/search-bar behavior on scroll.
  // See _HeaderVisibility above for what each state shows.
  _HeaderVisibility _headerVisibility = _HeaderVisibility.full;

  static const Color _primaryGreen = Color(0xFF1B4332);
  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _overdueRed = Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _all = PeminjamanService.getAll();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _loadFromSupabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    // Guard: a caller like _navigateAndRefresh awaits a pushed page that
    // could end in a logout (stack wiped via pushNamedAndRemoveUntil to
    // Login), which disposes this page before the await resolves.
    if (!mounted) return;
    setState(() => _all = PeminjamanService.getAll());
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkKembalikan() async {
    if (_selectedIds.isEmpty) return;
    final targets = _selectedIds.toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Tandai Kembali'),
        content: Text(
          'Tandai ${targets.length} dokumen terpilih sebagai telah kembali?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Tandai Kembali',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBulkSaving = true);
    List<String> berhasil = [];
    String? errorMsg;
    try {
      berhasil = await PeminjamanService.kembalikanBanyak(targets);
    } catch (e) {
      errorMsg = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _isBulkSaving = false;
      _selectionMode = false;
      _selectedIds.clear();
      _all = PeminjamanService.getAll();
    });

    final gagal = targets.length - berhasil.length;
    final petugas = AuthService.currentUser?.nama;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMsg != null
              ? 'Gagal menandai kembali: $errorMsg'
              : gagal == 0
              ? (petugas != null
                    ? '$petugas menandai ${berhasil.length} dokumen telah kembali.'
                    : '${berhasil.length} dokumen berhasil ditandai kembali.')
              : '${berhasil.length} dari ${targets.length} dokumen berhasil'
                    ' ditandai kembali ($gagal gagal).',
        ),
        backgroundColor: errorMsg != null || gagal > 0
            ? Colors.orange.shade700
            : _accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _loadFromSupabase() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await PeminjamanService.refresh();
      if (!mounted) return;
      setState(() {
        _all = PeminjamanService.getAll();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _all = PeminjamanService.getAll();
        _isLoading = false;
        _loadError = 'Gagal memuat data terbaru: $e';
      });
    }
  }

  // ─── PULL-TO-REFRESH: re-fetches from Supabase, then re-reads the cache.
  Future<void> _onPullRefresh() async {
    try {
      await PeminjamanService.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data terbaru: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _refresh();
  }

  void _navigateAndRefresh(String route) async {
    // Unfocus first: pushing a route while the search field (or another
    // TextField) still holds focus tears down its InheritedElement before
    // the keyboard/toolbar overlay detaches, tripping framework.dart's
    // '_dependents.isEmpty' assertion. Unfocusing first avoids it.
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.pushNamed(context, route);
    _refresh();
  }

  bool get _isFiltering =>
      _filterKecamatan != null ||
      _filterKelurahan != null ||
      _filterJenisHak != null ||
      _filterJenisDokumen != null;

  List<String> _kelurahanFor(String? kecamatan) {
    if (kecamatan == null) return const [];
    final direct = Data.kelurahan[kecamatan];
    if (direct != null && direct.isNotEmpty) return direct;
    final normalized = kecamatan.trim().toLowerCase();
    for (final entry in Data.kelurahan.entries) {
      if (entry.key.trim().toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return const [];
  }

  // ─── JENIS DOKUMEN–AWARE DISPLAY HELPERS (07.08.2026) ───
  // Buku Tanah / Surat Ukur / Warkah each carry a different set of
  // "which object is this" fields (see Peminjaman model + FormPage's
  // per-type sections). These helpers keep the card list, search, and
  // detail sheet all showing the right fields for whichever type a
  // given record actually is, instead of assuming Buku Tanah's
  // kecamatan/kelurahan/jenisHak/noHak fields always apply.
  String _objekTopLabel(Peminjaman p) {
    switch (p.jenisDokumen) {
      case 'Surat Ukur':
        return p.jenisHak;
      case 'Warkah':
        return (p.jenisWarkah?.isNotEmpty ?? false) ? p.jenisWarkah! : 'Warkah';
      default:
        return p.jenisHak;
    }
  }

  String _objekBottomLabel(Peminjaman p) {
    switch (p.jenisDokumen) {
      case 'Surat Ukur':
        return '${p.noTahunSuratUkur ?? '-'} • SU ${p.su ?? '-'}/GS ${p.gs ?? '-'}';
      case 'Warkah':
        return 'No. 208: ${p.no208 ?? '-'} (${p.tahunWarkah ?? '-'})';
      default:
        return '${p.noHak}/${p.kelurahan}';
    }
  }

  // Rows shown in the detail bottom sheet, conditional on jenisDokumen.
  // `row` is the same row-builder each caller already has in scope.
  List<Widget> _detailRowsFor(
    Peminjaman p,
    Widget Function(IconData icon, String label, String value) row,
  ) {
    switch (p.jenisDokumen) {
      case 'Surat Ukur':
        return [
          row(
            Icons.straighten_outlined,
            'Jenis Surat Ukur',
            p.jenisSuratUkur ?? '-',
          ),
          row(
            Icons.numbers_outlined,
            'No. & Tahun Surat Ukur',
            p.noTahunSuratUkur ?? '-',
          ),
          row(Icons.description_outlined, 'SU', p.su ?? '-'),
          row(Icons.map_outlined, 'GS (Gambar Situasi)', p.gs ?? '-'),
          row(
            Icons.shield_outlined,
            'Jenis Hak / Nomor Hak',
            '${p.jenisHak} - ${p.noHak}',
          ),
        ];
      case 'Warkah':
        return [
          row(Icons.folder_copy_outlined, 'Jenis Warkah', p.jenisWarkah ?? '-'),
          row(Icons.numbers_outlined, 'No. 208', p.no208 ?? '-'),
          row(Icons.event_outlined, 'Tahun Warkah', p.tahunWarkah ?? '-'),
        ];
      default: // Buku Tanah
        return [
          row(Icons.location_city_outlined, 'Kecamatan', p.kecamatan),
          row(Icons.map_outlined, 'Kelurahan', p.kelurahan),
          row(
            Icons.shield_outlined,
            'Jenis Hak / Nomor Hak',
            '${p.jenisHak} - ${p.noHak}',
          ),
        ];
    }
  }

  List<Peminjaman> get _pinjamanAktifRaw =>
      _all.where((p) => p.status == 'Dipinjam').toList();

  List<Peminjaman> get _pinjamanAktif {
    return _pinjamanAktifRaw.where((p) {
      if (_searchQuery.isNotEmpty) {
        final haystack =
            '${p.nama} ${p.noHak} ${p.kelurahan} ${p.jenisDokumen} '
                    '${p.jenisSuratUkur ?? ''} ${p.noTahunSuratUkur ?? ''} '
                    '${p.su ?? ''} ${p.gs ?? ''} ${p.jenisWarkah ?? ''} '
                    '${p.no208 ?? ''} ${p.tahunWarkah ?? ''}'
                .toLowerCase();
        if (!haystack.contains(_searchQuery)) return false;
      }
      if (_filterKecamatan != null && p.kecamatan != _filterKecamatan) {
        return false;
      }
      if (_filterKelurahan != null && p.kelurahan != _filterKelurahan) {
        return false;
      }
      if (_filterJenisHak != null && p.jenisHak != _filterJenisHak) {
        return false;
      }
      if (_filterJenisDokumen != null &&
          p.jenisDokumen != _filterJenisDokumen) {
        return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _filterKecamatan = null;
      _filterKelurahan = null;
      _filterJenisHak = null;
      _filterJenisDokumen = null;
    });
  }

  String _initials(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  // ─── PROSES KEMBALI ───
  void _konfirmasiKembalikan(Peminjaman p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Konfirmasi Pengembalian'),
        content: Text(
          'Tandai dokumen ${p.jenisDokumen} (${_objekBottomLabel(p)}) atas nama '
          '${p.nama} sebagai telah dikembalikan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              bool ok = false;
              String? errorMsg;
              try {
                ok = await PeminjamanService.kembalikan(p.id!);
              } catch (e) {
                errorMsg = e.toString();
              }
              if (!mounted) return;
              Navigator.pop(context);
              if (ok) _refresh();
              final petugas = AuthService.currentUser?.nama;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? (petugas != null
                              ? '$petugas menandai dokumen telah kembali.'
                              : 'Dokumen berhasil dikembalikan.')
                        : 'Gagal mengembalikan dokumen'
                              '${errorMsg != null ? ': $errorMsg' : ' (data tidak ditemukan / akses ditolak).'}',
                  ),
                  backgroundColor: ok ? _accentGreen : Colors.red.shade400,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  // ─── AJUKAN PERPANJANGAN WAKTU (dengan konfirmasi + alasan) ───
  // Item 4: Pegawai tidak lagi memperpanjang langsung — pengajuan masuk
  // antrean (PeminjamanService.ajukanPerpanjangan) dan menunggu keputusan
  // Admin lewat banner/notifikasi perpanjangan di HomePage. Pegawai DOES
  // still submit the request itself — only the approve/reject decision
  // (setujuiPerpanjangan/tolakPerpanjangan) is admin-only.
  Future<void> _perpanjangWaktu(Peminjaman p) async {
    // Defense in depth: the two call sites above already hide/disable
    // this action for non-owners, but guard here too in case a future
    // call site forgets to check first.
    final isOwner =
        p.diampuOleh == null || p.diampuOleh == AuthService.currentUser?.id;
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hanya pegawai yang mengajukan peminjaman ini yang dapat '
            'mengajukan perpanjangan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (p.isExtensionPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sudah ada pengajuan perpanjangan yang menunggu persetujuan Admin.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(2030),
      helpText: 'Pilih tanggal pengembalian baru',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _accentGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    final alasanController = TextEditingController();
    // Must live OUTSIDE the StatefulBuilder's builder callback — a local
    // var declared inside it gets re-initialized to null on every
    // setDialogState-triggered rebuild, which would silently wipe the
    // error message out the instant it's set.
    String? alasanError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text('Ajukan Perpanjangan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajukan perpanjangan batas waktu peminjaman '
                  '${p.jenisDokumen} (${_objekBottomLabel(p)}) '
                  'atas nama ${p.nama} menjadi '
                  '${picked.day.toString().padLeft(2, '0')}/'
                  '${picked.month.toString().padLeft(2, '0')}/${picked.year}?',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: alasanController,
                  maxLines: 2,
                  // Toolbar Copy/Paste dimatikan: field ini cuma dipakai
                  // sekali pakai untuk alasan, tidak butuh toolbar
                  // tersebut — dan toolbar itu ternyata sumber
                  // sebenarnya dari crash '_dependents.isEmpty' (overlay
                  // toolbar-nya belum sempat lepas saat dialog di-pop,
                  // unfocus() saja tidak cukup cepat karena masih butuh
                  // minimal satu frame). Mematikan toolbar menghilangkan
                  // overlay yang jadi sumber race-nya sama sekali.
                  contextMenuBuilder: (context, editableTextState) =>
                      const SizedBox.shrink(),
                  onChanged: (_) {
                    if (alasanError != null) {
                      setDialogState(() => alasanError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Alasan perpanjangan (wajib diisi)',
                    errorText: alasanError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pengajuan ini akan masuk antrean dan menunggu '
                  'persetujuan Admin.',
                  style: TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Unfocus + tunggu satu frame: unfocus() saja menjadwalkan
                  // rebuild tapi tidak langsung melepas overlay toolbar/
                  // handle selection dalam frame yang sama — makanya perlu
                  // jeda sebentar sebelum benar-benar pop.
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future.delayed(const Duration(milliseconds: 50));
                  if (context.mounted) Navigator.pop(context, false);
                },
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Item #4: alasan is not optional — none of the inputs
                  // in this form are — so block submission and surface an
                  // inline error instead of silently sending an empty
                  // reason through to the admin's approval queue.
                  if (alasanController.text.trim().isEmpty) {
                    setDialogState(() => alasanError = 'Alasan wajib diisi.');
                    return;
                  }
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future.delayed(const Duration(milliseconds: 50));
                  if (context.mounted) Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Ajukan'),
              ),
            ],
          );
        },
      ),
    );

    final alasan = alasanController.text.trim();
    alasanController.dispose();
    if (confirmed != true) return;

    bool ok = false;
    String? errorMsg;
    try {
      ok = await PeminjamanService.ajukanPerpanjangan(p.id!, picked, alasan);
    } catch (e) {
      errorMsg = e.toString();
    }
    if (!mounted) return;
    if (ok) _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Pengajuan perpanjangan terkirim, menunggu persetujuan Admin.'
              : errorMsg ?? 'Gagal mengajukan perpanjangan. Coba lagi.',
        ),
        backgroundColor: ok ? _accentGreen : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showDetail(Peminjaman p) {
    final isOwner =
        p.diampuOleh == null || p.diampuOleh == AuthService.currentUser?.id;
    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: _accentGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFD8F3DC),
                      child: Text(
                        _initials(p.nama),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nama,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            p.seksi,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.isOverdue
                            ? const Color(0xFFFDE2E1)
                            : const Color(0xFFFFF3D9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p.isOverdue
                            ? 'Terlambat ${p.hariTerlambat} hari'
                            : 'Sedang Dipinjam',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.isOverdue
                              ? _overdueRed
                              : const Color(0xFFB07A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 18),
                row(Icons.category_outlined, 'Jenis Dokumen', p.jenisDokumen),
                ..._detailRowsFor(p, row),
                row(Icons.description_outlined, 'Keperluan', p.keperluan),
                row(
                  Icons.calendar_month_outlined,
                  'Tanggal Pinjam',
                  p.tanggalPinjamFormatted,
                ),
                row(
                  Icons.event_available_outlined,
                  'Batas Pengembalian',
                  p.tanggalKembaliFormatted,
                ),
                if (p.approvedByMessage != null)
                  row(
                    Icons.how_to_reg_outlined,
                    'Disetujui Oleh',
                    p.disetujuiOlehNama!,
                  ),
                // This is the page where extensions actually get
                // requested/approved, so it's the most relevant place
                // for this — not just History after the fact.
                if (p.extensionApprovedByMessage != null)
                  row(
                    Icons.more_time_outlined,
                    'Perpanjangan Disetujui Oleh',
                    p.perpanjanganDisetujuiOlehNama!,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _konfirmasiKembalikan(p);
                        },
                        icon: const Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Proses Kembali',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (p.isOverdue) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (!isOwner || p.isExtensionPending)
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _perpanjangWaktu(p);
                                },
                          icon: Icon(
                            !isOwner
                                ? Icons.lock_outline
                                : p.isExtensionPending
                                ? Icons.hourglass_top_rounded
                                : Icons.more_time,
                            size: 18,
                          ),
                          label: Text(
                            !isOwner
                                ? 'Perpanjang'
                                : p.isExtensionPending
                                ? 'Menunggu Persetujuan'
                                : 'Perpanjang',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: (!isOwner || p.isExtensionPending)
                                ? Colors.black45
                                : _overdueRed,
                            side: BorderSide(
                              color: (!isOwner || p.isExtensionPending)
                                  ? Colors.black26
                                  : _overdueRed,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Dipakai oleh AppDrawer: Dashboard pakai pushReplacement, sisanya
  // push + refresh saat kembali (sama seperti HomePage).
  void _onDrawerNavigate(String route) {
    if (route == AppRoutes.home) {
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      _navigateAndRefresh(route);
    }
  }

  // ─── HEADER (gradient, rounded-bottom, matches HomePage) ───
  Widget _buildHeader() {
    final aktif = _pinjamanAktifRaw;
    final overdueCount = aktif.where((p) => p.isOverdue).length;
    final tepatWaktu = aktif.length - overdueCount;

    Widget stat(
      IconData icon,
      String value,
      String label, {
      Color? valueColor,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryGreen, _accentGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppTopBar(title: 'Pengembalian'),
              const SizedBox(height: 14),
              Row(
                children: [
                  stat(
                    Icons.sync_alt_rounded,
                    '${aktif.length}',
                    'Pinjaman\nAktif',
                  ),
                  const SizedBox(width: 10),
                  stat(
                    Icons.check_circle_outline,
                    '$tepatWaktu',
                    'Tepat\nWaktu',
                  ),
                  const SizedBox(width: 10),
                  stat(
                    Icons.warning_amber_rounded,
                    '$overdueCount',
                    'Sudah\nTerlambat',
                    valueColor: overdueCount > 0
                        ? const Color(0xFFFFB4AC)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FLOATING SEARCH + FILTER BAR ───
  Widget _buildFloatingSearchBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Masukkan Nomor Hak...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 13.5),
                prefixIcon: Icon(Icons.search, color: Colors.black38, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _isFiltering ? _accentGreen : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: _isFiltering ? Colors.white : _accentGreen,
                    ),
                  ),
                  if (_isFiltering)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    String? tempKecamatan = _filterKecamatan;
    String? tempKelurahan = _filterKelurahan;
    String? tempJenisHak = _filterJenisHak;
    String? tempJenisDokumen = _filterJenisDokumen;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final kelurahanOptions = _kelurahanFor(tempKecamatan);

            Widget dropdown({
              required String placeholder,
              required List<String> items,
              required String? value,
              required ValueChanged<String?> onChanged,
              bool isDisabled = false,
            }) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? const Color(0xFFEEEEEE)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : null,
                    isExpanded: true,
                    hint: Text(
                      placeholder,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDisabled ? Colors.black26 : Colors.black38,
                      ),
                    ),
                    items: isDisabled
                        ? null
                        : items
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(
                                    item,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                    onChanged: isDisabled ? null : onChanged,
                  ),
                ),
              );
            }

            Widget jenisDokumenChip(String label) {
              final selected = tempJenisDokumen == label;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setSheetState(() {
                    tempJenisDokumen = selected ? null : label;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? _accentGreen : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Pengembalian',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempKecamatan = null;
                            tempKelurahan = null;
                            tempJenisHak = null;
                            tempJenisDokumen = null;
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jenis Dokumen',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      jenisDokumenChip('Buku Tanah'),
                      jenisDokumenChip('Surat Ukur'),
                      jenisDokumenChip('Warkah'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kecamatan',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  dropdown(
                    placeholder: 'Semua Kecamatan',
                    items: Data.kecamatan,
                    value: tempKecamatan,
                    onChanged: (v) => setSheetState(() {
                      tempKecamatan = v;
                      tempKelurahan = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kelurahan',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  dropdown(
                    placeholder: tempKecamatan == null
                        ? 'Pilih Kecamatan dahulu'
                        : 'Semua Kelurahan',
                    items: kelurahanOptions,
                    value: tempKelurahan,
                    isDisabled: tempKecamatan == null,
                    onChanged: (v) => setSheetState(() => tempKelurahan = v),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Jenis Hak',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  dropdown(
                    placeholder: 'Semua Jenis Hak',
                    items: Data.jenisHak,
                    value: tempJenisHak,
                    onChanged: (v) => setSheetState(() => tempJenisHak = v),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterKecamatan = tempKecamatan;
                          _filterKelurahan = tempKelurahan;
                          _filterJenisHak = tempJenisHak;
                          _filterJenisDokumen = tempJenisDokumen;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── CARD ITEM ───
  Widget _item(Peminjaman p) {
    final accent = p.isOverdue ? _overdueRed : const Color(0xFFB07A00);
    final selected = _selectedIds.contains(p.id);
    // Item #1 fix: the "Perpanjang" button is only meaningful for the
    // pegawai who actually borrowed this document — see the ownership
    // gate in PeminjamanService.ajukanPerpanjangan for the enforcement
    // side of this. Legacy rows with no recorded owner (diampuOleh ==
    // null) are treated as open, same as the service-layer check.
    final isOwner =
        p.diampuOleh == null || p.diampuOleh == AuthService.currentUser?.id;

    return Material(
      color: selected ? _accentGreen.withOpacity(0.06) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _selectionMode
            ? () => _toggleSelected(p.id!)
            : () => _showDetail(p),
        onLongPress: () {
          if (!_selectionMode) {
            setState(() => _selectionMode = true);
          }
          _toggleSelected(p.id!);
        },
        child: Container(
          decoration: BoxDecoration(
            // Was missing entirely before — a BoxDecoration with no
            // `color` is transparent, so this card was just showing the
            // page's own background color through it.
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(color: _accentGreen, width: 1.5)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.06),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Center(
                      child: Checkbox(
                        value: selected,
                        activeColor: _accentGreen,
                        onChanged: (_) => _toggleSelected(p.id!),
                      ),
                    ),
                  ),
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              // Wraps the profile trigger area
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showUserProfileModal(context, p),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFD8F3DC),
                                      child: Text(
                                        _initials(p.nama),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.nama,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize:
                                                  15, // or 16 depending on the page
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.seksi,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: p.isOverdue
                                    ? const Color(0xFFFDE2E1)
                                    : const Color(0xFFFFF3D9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                p.isOverdue
                                    ? 'Terlambat ${p.hariTerlambat} hari'
                                    : 'Sedang Dipinjam',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            // Brightened from flat #F5F5F5 to a soft
                            // green-tinted highlight — same reasoning as
                            // history_page.dart's identical box.
                            color: _accentGreen.withOpacity(0.06),
                            border: Border.all(
                              color: _accentGreen.withOpacity(0.15),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.jenisDokumen} · ${_objekTopLabel(p)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black38,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _objekBottomLabel(p),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.isOverdue ? 'BATAS WAKTU' : 'TGL PINJAM',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black38,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    p.isOverdue
                                        ? p.tanggalKembaliFormatted
                                        : p.tanggalPinjamFormatted,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: p.isOverdue
                                          ? _overdueRed
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Tombol Proses Kembali / Perpanjang
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _konfirmasiKembalikan(p),
                                icon: const Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Proses Kembali',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            if (p.isOverdue) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: !isOwner
                                    ? Tooltip(
                                        message:
                                            'Hanya pegawai yang mengajukan '
                                            'peminjaman ini yang dapat '
                                            'mengajukan perpanjangan.',
                                        child: OutlinedButton.icon(
                                          onPressed: null,
                                          icon: const Icon(
                                            Icons.lock_outline,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Perpanjang',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.black38,
                                            side: const BorderSide(
                                              color: Colors.black12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                        ),
                                      )
                                    : OutlinedButton.icon(
                                        onPressed: p.isExtensionPending
                                            ? null
                                            : () => _perpanjangWaktu(p),
                                        icon: Icon(
                                          p.isExtensionPending
                                              ? Icons.hourglass_top_rounded
                                              : Icons.more_time,
                                          size: 18,
                                        ),
                                        label: Text(
                                          p.isExtensionPending
                                              ? 'Menunggu Persetujuan'
                                              : 'Perpanjang',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: p.isExtensionPending
                                              ? Colors.black45
                                              : _overdueRed,
                                          side: BorderSide(
                                            color: p.isExtensionPending
                                                ? Colors.black26
                                                : _overdueRed,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserProfileModal(BuildContext context, Peminjaman p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFD8F3DC),
              child: Text(
                _initials(p.nama),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4332),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              p.nama,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                p.seksi,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Dipakai oleh AppBottomNav ───
  void _onNavTap(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case 1:
        _navigateAndRefresh(AppRoutes.archive);
        break;
      case 2:
        _navigateAndRefresh(AppRoutes.history);
        break;
      case 3:
        setState(() => _selectedNavIndex = 3);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktif = _pinjamanAktif;
    final overdueCount = aktif.where((p) => p.isOverdue).length;

    return BackToHome(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        drawer: AppDrawer(
          active: DrawerSection.pengembalian,
          onNavigate: _onDrawerNavigate,
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectionMode && _selectedIds.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} dokumen dipilih',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isBulkSaving ? null : _bulkKembalikan,
                        icon: _isBulkSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                        label: const Text(
                          'Tandai Kembali',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            AppBottomNav(
              activeIndex: _selectedNavIndex,
              onItemSelected: _onNavTap,
            ),
          ],
        ),
        floatingActionButton: AppScanFab(
          onTap: () => _navigateAndRefresh(AppRoutes.scan),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        body: Column(
          children: [
            // Item #6 (revisi): dua blok yang animasinya independen, jadi
            // "full" dan "compact" nggak harus nge-lerp dari/ke ukuran
            // yang sama — masing-masing AnimatedAlign cuma pernah punya
            // dua kemungkinan tinggi (0 atau tinggi asli kontennya
            // sendiri), jadi slide-nya tetap mulus walau daftar di bawah
            // pendek/kosong. Lihat NotificationListener di sekitar list
            // untuk logika _headerVisibility-nya.
            //
            // BUG FIX (tetap berlaku): ClipRect clips to the Stack's own
            // bounds, dan bare Stack cuma ngukur dari non-positioned
            // children-nya (_buildHeader() doang). Search bar-nya
            // Positioned(bottom: -24) supaya sengaja nongol 24px di bawah
            // header buat nutup jahitan header/body, tapi bagian yang
            // nongol itu jatuh di luar bounds Stack (dan ClipRect-nya)
            // jadi kepotong. Fix-nya: sisain 24px itu (plus sedikit extra
            // buat shadow card-nya) di dalam Stack lewat spacer, biar box
            // ClipRect-nya cukup tinggi buat nampung seluruh floating bar.
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: _headerVisibility == _HeaderVisibility.full
                    ? 1.0
                    : 0.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [_buildHeader(), const SizedBox(height: 40)],
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: _buildFloatingSearchBar(),
                    ),
                  ],
                ),
              ),
            ),
            // Compact bar: search bar doang, tanpa header gradient — ini
            // yang tampil begitu user geser dari posisi paling atas,
            // entah scroll ke atas ATAU ke bawah (lihat NotificationListener:
            // cuma `atTop` yang dicek, bukan arah scroll). Header
            // gradient/stat lengkap cuma balik pas beneran nyampe atas.
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: _headerVisibility == _HeaderVisibility.compact
                    ? 1.0
                    : 0.0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: _buildFloatingSearchBar(),
                ),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            //   child: JenisDokumenBreakdown(
            //     // Scoped to _pinjamanAktifRaw (status == 'Dipinjam'), not
            //     // the whole archive — this page only ever lists active
            //     // loans, so a breakdown of everything ever borrowed
            //     // (including already-returned docs) would be misleading
            //     // here. Home/History use the unscoped app-wide counts
            //     // instead, which fits what those pages actually show.
            //     stats: [
            //       JenisDokumenStat(
            //         jenis: 'Buku Tanah',
            //         icon: Icons.menu_book_outlined,
            //         count: _pinjamanAktifRaw
            //             .where((p) => p.jenisDokumen == 'Buku Tanah')
            //             .length,
            //         color: _accentGreen,
            //       ),
            //       JenisDokumenStat(
            //         jenis: 'Surat Ukur',
            //         icon: Icons.straighten_outlined,
            //         count: _pinjamanAktifRaw
            //             .where((p) => p.jenisDokumen == 'Surat Ukur')
            //             .length,
            //         color: const Color(0xFFC08A3E),
            //       ),
            //       JenisDokumenStat(
            //         jenis: 'Warkah',
            //         icon: Icons.folder_copy_outlined,
            //         count: _pinjamanAktifRaw
            //             .where((p) => p.jenisDokumen == 'Warkah')
            //             .length,
            //         color: const Color(0xFF5C5FCD),
            //       ),
            //     ],
            //   ),
            // ),
            if (_isFiltering)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt,
                      size: 14,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Filter aktif',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _resetFilters,
                      child: Text(
                        'Hapus Filter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _accentGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pinjaman Aktif',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8F3DC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${aktif.length} Berkas',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primaryGreen,
                          ),
                        ),
                      ),
                      if (aktif.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _toggleSelectionMode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _selectionMode
                                  ? _accentGreen
                                  : _accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _selectionMode ? 'Batal' : 'Pilih',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectionMode
                                    ? Colors.white
                                    : _accentGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE2E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: _overdueRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _overdueRed,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadFromSupabase,
                        child: const Text(
                          'Coba lagi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _overdueRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final metrics = notification.metrics;

                  // Posisi, bukan arah — lihat penjelasan lengkap di
                  // history_page.dart. Selain "di paling atas" (atau
                  // daftarnya kependekan buat discroll sama sekali) →
                  // compact, titik — search bar selalu tampil begitu
                  // geser dari atas, nggak peduli arah scroll-nya.
                  final atTop =
                      metrics.maxScrollExtent <= 0 || metrics.pixels <= 0;
                  final target = atTop
                      ? _HeaderVisibility.full
                      : _HeaderVisibility.compact;
                  if (_headerVisibility != target) {
                    setState(() => _headerVisibility = target);
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: _onPullRefresh,
                  color: _accentGreen,
                  child: _isLoading && _all.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.55,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ],
                        )
                      : aktif.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.55,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 36,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 92,
                                        height: 92,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD8F3DC),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.inventory_2_outlined,
                                          size: 40,
                                          color: _accentGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        _pinjamanAktifRaw.isEmpty
                                            ? 'Tidak Ada Pinjaman Aktif'
                                            : 'Tidak Ada Hasil',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _pinjamanAktifRaw.isEmpty
                                            ? 'Semua dokumen sudah dikembalikan. '
                                                  'Dokumen yang sedang dipinjam '
                                                  'akan muncul di sini.'
                                            : 'Coba ubah kata kunci pencarian '
                                                  'atau filter yang sedang aktif.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black45,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      if (_pinjamanAktifRaw.isEmpty)
                                        OutlinedButton.icon(
                                          onPressed: () => _navigateAndRefresh(
                                            AppRoutes.form,
                                          ),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Catat Peminjaman'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _accentGreen,
                                            side: const BorderSide(
                                              color: _accentGreen,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 22,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                        )
                                      else
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            _resetFilters();
                                          },
                                          child: Text(
                                            'Hapus Pencarian & Filter',
                                            style: TextStyle(
                                              color: _accentGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: aktif.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _item(aktif[index]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
