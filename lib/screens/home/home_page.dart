import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/peminjaman_service.dart';
import '../../services/auth_service.dart';
import '../../models/peminjaman.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_scan_fab.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/jenis_dokumen_breakdown.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedNavIndex = 0;

  // Ganti / tambah path sesuai foto yang kamu taruh di assets/images/
  final List<String> _bannerImages = const [
    'assets/bpn1.jpg',
    'assets/bpn2.jpg',
    'assets/bpn3.jpg',
  ];

  // ─── Infinite-loop carousel ───────────────────────────────────────
  // PageView has no built-in "wrap around" mode, so this uses the usual
  // trick: itemCount is a large multiple of the real image count, and
  // itemBuilder maps each huge index back down with % _bannerImages.
  // length. Starting in the middle of that huge range means there's
  // effectively unlimited room to swipe left OR right without ever
  // hitting a real start/end — from the user's perspective it just
  // loops forever in both directions.
  static const _loopMultiplier = 2000;
  late final int _loopItemCount = _bannerImages.length * _loopMultiplier;
  late final int _loopInitialPage =
      (_loopItemCount ~/ 2) - ((_loopItemCount ~/ 2) % _bannerImages.length);

  late final PageController _bannerController = PageController(
    // Item: banner carousel — less than 1.0 leaves a sliver of the
    // previous/next card visible on each side, so swiping reads as
    // "sliding through a connected strip" instead of one full-bleed
    // image cutting to the next (see Klik Indomaret reference).
    viewportFraction: 0.92,
    initialPage: _loopInitialPage,
  );
  // Raw (huge, un-modded) page index — kept in sync with the controller
  // so the scale/fade math below stays correct. Use
  // `_currentBanner % _bannerImages.length` wherever the *real* image
  // index is needed (dot indicator, etc).
  int _currentBanner = 0; // set to _loopInitialPage in initState below

  @override
  void initState() {
    super.initState();
    _currentBanner = _loopInitialPage;
    // Guard: HomePage is reachable directly by route name, so if there's
    // no active session (hot restart mid-session, deep link, etc.) bounce
    // straight back to Login instead of rendering with a null user.
    if (!AuthService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      });
    }
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  void _navigateAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    // Guard: if the pushed page ended in a logout (pushNamedAndRemoveUntil
    // to Login), HomePage is disposed by the time this await resolves —
    // calling setState() here would crash without this check.
    if (mounted) setState(() {});
  }

  // ─── PULL-TO-REFRESH: re-fetches from Supabase and rebuilds. Wraps
  // PeminjamanService.refresh() (network) with error handling so a
  // dropped connection just shows a snackbar instead of crashing the
  // refresh gesture.
  Future<void> _onRefresh() async {
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
    if (!mounted) return;
    setState(() {});
  }

  // ─── Sapaan berdasarkan jam saat ini, bukan teks statis ───
  String _greetingByTime() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Selamat pagi,';
    if (hour < 15) return 'Selamat siang,';
    if (hour < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  // ─── Item 1: notif badge count moved into NotificationBell itself —
  // see lib/widgets/notification_bell.dart. It reads PeminjamanService/
  // AuthService directly, so this page no longer needs to track or pass
  // a count down.

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = 0);
        break;
      case 1:
        _navigateAndRefresh(AppRoutes.history);
        break;
      case 2:
        _navigateAndRefresh(AppRoutes.returnPage);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  // ─── Dipakai oleh AppDrawer: memutuskan pushReplacement (Dashboard) vs
  // push+refresh (halaman lain) tanpa AppDrawer perlu tahu bedanya.
  void _onDrawerNavigate(String route) {
    if (route == AppRoutes.home) return; // sudah di Dashboard
    _navigateAndRefresh(route);
  }

  // ─── HEADER (gradient AppBar area + greeting) ───
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.accentGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: menu, title, notif, avatar — see widgets/app_top_bar.dart
              const AppTopBar(title: 'Arsip Pertanahan Cilegon'),
              const SizedBox(height: 12),
              // Greeting card (mengambang, ala "Halo, Budi Disini!")
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greetingByTime(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Halo, ${AuthService.currentUser?.nama ?? 'Pengguna'}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (AuthService.currentUser?.jabatan != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        AuthService.currentUser!.jabatan,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── QUICK ACCESS ICON GRID (ala grid Cari Berkas / Swapching dll) ───
  Widget _buildQuickAccessGrid() {
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.edit_document,
        'label': 'Form\nPeminjaman',
        'color': const Color(0xFF2D6A4F),
        'route': AppRoutes.form,
      },
      {
        'icon': Icons.list_alt,
        'label': 'Daftar\nPeminjaman',
        'color': const Color(0xFF2D6A4F),
        'route': AppRoutes.history,
      },
      {
        'icon': Icons.assignment_return,
        'label': 'Pengem-\nbalian',
        'color': const Color(0xFF2D6A4F),
        'route': AppRoutes.returnPage,
      },
      {
        'icon': Icons.qr_code_scanner,
        'label': 'Scan QR\nCode',
        'color': const Color(0xFF5C5FCD),
        'route': AppRoutes.scan,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            return GestureDetector(
              onTap: () => _navigateAndRefresh(item['route'] as String),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── IMAGE CAROUSEL BANNER (foto kantor, swipeable + dots) ───
  // Full-bleed, square-cornered, edge-to-edge cards — the next/previous
  // card only peeks in as a thin sliver at the screen edge (viewportFraction
  // close to 1 on the controller above), matching the Klik Indomaret
  // reference rather than the earlier rounded-card-with-gaps look.
  // Loops infinitely in both directions — see the loop fields above.
  Widget _buildImageCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: AnimatedBuilder(
            animation: _bannerController,
            builder: (context, child) {
              return PageView.builder(
                controller: _bannerController,
                itemCount: _loopItemCount,
                onPageChanged: (i) => setState(() => _currentBanner = i),
                itemBuilder: (context, index) {
                  final imageIndex = index % _bannerImages.length;

                  // Falls back to a plain 0 offset before the controller
                  // is attached to its viewport on the very first frame.
                  double page = _currentBanner.toDouble();
                  if (_bannerController.hasClients &&
                      _bannerController.position.haveDimensions) {
                    page = _bannerController.page ?? page;
                  }
                  final distance = (page - index).abs().clamp(0.0, 1.0);
                  final opacity = 1 - (distance * 0.25);

                  return Opacity(
                    opacity: opacity,
                    child: Padding(
                      // Small gap between peeking cards, same spacing as
                      // the original rounded-card version.
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              _bannerImages[imageIndex],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryGreen,
                                          AppTheme.accentGreen,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.apartment_rounded,
                                        color: Colors.white38,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.55),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 16,
                              bottom: 14,
                              right: 16,
                              child: Text(
                                'Kantor Pertanahan Kota Cilegon',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_bannerImages.length, (index) {
            final isActive = index == (_currentBanner % _bannerImages.length);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.accentGreen : Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─── JENIS DOKUMEN BREAKDOWN (08.08.2026) ───
  // Colors intentionally reuse what's already in the app's palette
  // instead of inventing a new one: green is AppTheme's own accent,
  // gold matches the Login/Signup header accent, purple matches the
  // "Simpan Data" button on FormPage — so this card reads as part of
  // the same design language, not a bolted-on new widget.
  Widget _buildJenisDokumenBreakdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: JenisDokumenBreakdown(
        stats: [
          JenisDokumenStat(
            jenis: 'Buku Tanah',
            icon: Icons.menu_book_outlined,
            count: PeminjamanService.getCountBukuTanah(),
            color: AppTheme.accentGreen,
          ),
          JenisDokumenStat(
            jenis: 'Surat Ukur',
            icon: Icons.straighten_outlined,
            count: PeminjamanService.getCountSuratUkur(),
            color: const Color(0xFFC08A3E),
          ),
          JenisDokumenStat(
            jenis: 'Warkah',
            icon: Icons.folder_copy_outlined,
            count: PeminjamanService.getCountWarkah(),
            color: const Color(0xFF5C5FCD),
          ),
        ],
        onTapJenis: (jenis) => _navigateAndRefresh(AppRoutes.history),
      ),
    );
  }

  // ─── COMPACT STAT CHIPS (Aktif / Kembali / Terlambat) ───
  Widget _buildStatChips() {
    final aktif = PeminjamanService.getSedangDipinjam();
    final kembali = PeminjamanService.getTelahKembali();
    final terlambat = PeminjamanService.getTerlambat();

    Widget chip({
      required IconData icon,
      required Color color,
      required String value,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          chip(
            icon: Icons.sync_alt_rounded,
            color: Colors.orange,
            value: aktif.toString(),
            label: 'Sedang\nDipinjam',
            onTap: () => _navigateAndRefresh(AppRoutes.returnPage),
          ),
          chip(
            icon: Icons.inventory_2_outlined,
            color: Colors.green,
            value: kembali.toString(),
            label: 'Telah\nKembali',
            onTap: () => _navigateAndRefresh(AppRoutes.history),
          ),
          chip(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.dangerRed,
            value: terlambat.toString(),
            label: 'Terlambat\nKembali',
            onTap: () => _navigateAndRefresh(AppRoutes.returnPage),
          ),
        ],
      ),
    );
  }

  // ─── INFO TERBARU (aktivitas peminjaman terbaru, horizontal cards) ───
  // ─── JENIS DOKUMEN DISPLAY HELPERS (07.08.2026) ───
  // Buku Tanah/Surat Ukur/Warkah each leave different Peminjaman fields
  // as '-' placeholders (see form_page.dart / peminjaman.dart) since
  // e.g. kelurahan/jenisHak genuinely don't apply to a Warkah loan. These
  // pick whichever fields are actually meaningful for a given p's type,
  // instead of the old hardcoded p.jenisHak / '${p.noHak}/${p.kelurahan}'
  // which would just show "-" for anything that isn't Buku Tanah.

  /// Combines the document type with its type-specific sub-label, e.g.
  /// "Buku Tanah • Hak Milik", "Surat Ukur • Ukur Bidang", "Warkah •
  /// Persyaratan Umum".
  String _dokumenTypeLabel(Peminjaman p) {
    switch (p.jenisDokumen) {
      case 'Surat Ukur':
        return '${p.jenisDokumen} • ${p.jenisSuratUkur ?? '-'}';
      case 'Warkah':
        return '${p.jenisDokumen} • ${p.jenisWarkah ?? '-'}';
      case 'Buku Tanah':
      default:
        return '${p.jenisDokumen} • ${p.jenisHak}';
    }
  }

  /// The identifying reference number line — which fields make sense
  /// here differs by type (a Warkah has no no_hak/kelurahan at all).
  String _dokumenIdentifier(Peminjaman p) {
    switch (p.jenisDokumen) {
      case 'Surat Ukur':
        return 'SU ${p.su ?? '-'} • No. Hak ${p.noHak}';
      case 'Warkah':
        return 'No. 208: ${p.no208 ?? '-'}';
      case 'Buku Tanah':
      default:
        return '${p.noHak}/${p.kelurahan}';
    }
  }

  Widget _buildRecentActivity() {
    final all = List<Peminjaman>.from(PeminjamanService.getAll())
      ..sort((a, b) => b.tanggalPinjam.compareTo(a.tanggalPinjam));
    final recent = all.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aktivitas Terbaru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateAndRefresh(AppRoutes.history),
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Belum ada aktivitas peminjaman.',
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final p = recent[index];
                final overdue = p.isOverdue;
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.barcode,
                    arguments: {
                      'noHak': p.noHak,
                      'nama': p.nama,
                      'kelurahan': p.kelurahan,
                      'jenisHak': p.jenisHak,
                      'jenisDokumen': p.jenisDokumen,
                      'tanggalPinjam': p.tanggalPinjamFormatted,
                      'tanggalKembali': p.tanggalKembaliFormatted,
                    },
                  ),
                  child: Container(
                    width: 190,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _dokumenTypeLabel(p),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: overdue
                                    ? const Color(0xFFFDE2E1)
                                    : p.status == 'Dipinjam'
                                    ? const Color(0xFFFFF3D9)
                                    : const Color(0xFFD8F3DC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                overdue
                                    ? 'Terlambat'
                                    : (p.status == 'Dipinjam'
                                          ? 'Dipinjam'
                                          : 'Kembali'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: overdue
                                      ? AppTheme.dangerRed
                                      : p.status == 'Dipinjam'
                                      ? const Color(0xFFB07A00)
                                      : AppTheme.accentGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dokumenIdentifier(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Mulai: ${p.tanggalPinjamFormatted}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_available_outlined,
                              size: 11,
                              color: Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Batas: ${p.tanggalKembaliFormatted}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ─── ITEM 2 (Dashboard counters, khusus Pegawai): "Minjam brp / Blm
  // kembali brp" milik pegawai yang sedang login, bukan angka kantor
  // secara keseluruhan (itu tugas _buildStatChips di bawah). Cuma
  // ditampilkan untuk role Pegawai — Admin sudah lihat gambaran penuh
  // lewat _buildStatChips + banner persetujuan.
  Widget _buildPersonalSummary() {
    if (!AuthService.isPegawai) return const SizedBox.shrink();

    final minjam = PeminjamanService.getMinjamBrp();
    final belumKembali = PeminjamanService.getBelumKembaliBrp();

    Widget stat(String value, String label, Color color) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            stat(
              minjam.toString(),
              'Sedang Anda\npinjam',
              AppTheme.primaryGreen,
            ),
            Container(width: 1, height: 32, color: Colors.black12),
            stat(
              belumKembali.toString(),
              'Belum Anda\nkembalikan',
              AppTheme.dangerRed,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Item 3 lanjutan (approval flow, khusus Admin): banner kecil kalau
  // ada pengajuan perpanjangan yang menunggu keputusan. Layar approval-nya
  // sendiri belum dibangun, jadi tap-nya masih placeholder — sama seperti
  // pola "belum tersedia" yang sudah dipakai di tempat lain.
  Widget _buildAdminExtensionBanner() {
    if (!AuthService.isAdmin) return const SizedBox.shrink();

    final pending = PeminjamanService.getPengajuanPerpanjangan();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _showExtensionApprovalSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.pending_actions, color: Color(0xFFB07A00)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${pending.length} pengajuan perpanjangan menunggu persetujuan Anda.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB07A00),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB07A00),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Item 1 (banner), khusus Pegawai: alert kalau ada dokumen milik
  // sendiri yang sudah lewat batas — mirror visual banner Admin di atas,
  // supaya Pegawai juga dapat "alert di atas layar", bukan cuma angka di
  // ringkasan pribadi.
  Widget _buildPegawaiOverdueBanner() {
    if (!AuthService.isPegawai) return const SizedBox.shrink();

    final belumKembali = PeminjamanService.getBelumKembaliBrp();
    if (belumKembali == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => _navigateAndRefresh(AppRoutes.returnPage),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDE2E1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.dangerRed,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$belumKembali dokumen Anda sudah lewat batas waktu pengembalian.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dangerRed,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.dangerRed,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Item 4: bottom sheet approval perpanjangan untuk Admin. Dibuka dari
  // banner di atas maupun dari bell notifikasi. Pakai StatefulBuilder biar
  // list-nya bisa refresh sendiri setelah Setujui/Tolak tanpa nutup sheet.
  void _showExtensionApprovalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final pending = PeminjamanService.getPengajuanPerpanjangan();

            Future<void> _decide(String noHak, bool approve) async {
              final ok = approve
                  ? await PeminjamanService.setujuiPerpanjangan(noHak)
                  : await PeminjamanService.tolakPerpanjangan(noHak);
              if (!ok) return;
              if (!mounted) return;
              setSheetState(() {});
              setState(() {}); // refresh badge + banner di HomePage
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approve
                        ? 'Perpanjangan $noHak disetujui.'
                        : 'Perpanjangan $noHak ditolak.',
                  ),
                  backgroundColor: approve
                      ? AppTheme.accentGreen
                      : AppTheme.dangerRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              if (pending.length <= 1) Navigator.pop(sheetContext);
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
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
                  const Text(
                    'Pengajuan Perpanjangan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pending.length} pengajuan menunggu keputusan.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Tidak ada pengajuan yang menunggu.',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pending.length,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          final p = pending[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.nama} — ${_dokumenIdentifier(p)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Batas saat ini: ${p.tanggalKembaliFormatted}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                'Diajukan menjadi: ${p.requestedTanggalKembali != null ? '${p.requestedTanggalKembali!.day.toString().padLeft(2, '0')}/${p.requestedTanggalKembali!.month.toString().padLeft(2, '0')}/${p.requestedTanggalKembali!.year}' : '-'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              if (p.extensionReason != null &&
                                  p.extensionReason!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Alasan: ${p.extensionReason}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _decide(p.noHak, false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.dangerRed,
                                        side: const BorderSide(
                                          color: AppTheme.dangerRed,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _decide(p.noHak, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentGreen,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Setujui',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: AppDrawer(
        active: DrawerSection.dashboard,
        onNavigate: _onDrawerNavigate,
      ),
      bottomNavigationBar: AppBottomNav(
        activeIndex: _selectedNavIndex,
        onItemSelected: _onNavTap,
      ),
      floatingActionButton: AppScanFab(
        onTap: () => _navigateAndRefresh(AppRoutes.scan),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.accentGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildAdminExtensionBanner(),
              _buildPegawaiOverdueBanner(),
              _buildPersonalSummary(),
              const SizedBox(height: 10),
              _buildQuickAccessGrid(),
              const SizedBox(height: 22),
              _buildImageCarousel(),
              const SizedBox(height: 20),
              _buildStatChips(),
              const SizedBox(height: 14),
              _buildJenisDokumenBreakdown(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
