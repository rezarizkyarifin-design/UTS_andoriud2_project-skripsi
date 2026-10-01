import 'dart:async';

import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../services/peminjaman_service.dart';
import '../services/auth_service.dart';
import '../services/admin_request_service.dart';
import '../../models/peminjaman.dart';
import '../../models/admin_request.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_scan_fab.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/jenis_dokumen_breakdown.dart';

// ─── NOTIF PANEL DATA MODEL (14.09.2026) ───────────────────────────
// Plain data holder for one row inside the collapsible admin
// notifications panel below. Keeping this as a tiny class (instead of
// building the Widgets directly inside _collectAdminNotifItems) means
// the "how many are there / is any of them urgent" logic in
// _buildAdminNotificationsPanel can inspect the list before deciding
// how to render the header, without needing to already have built
// Row/Container trees just to count them.
class _NotifItem {
  final IconData icon;
  final Color color;
  final Color bg;
  final String message;
  final VoidCallback onTap;
  final bool urgent;

  _NotifItem({
    required this.icon,
    required this.color,
    required this.bg,
    required this.message,
    required this.onTap,
    this.urgent = false,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final int _selectedNavIndex = 0;

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

  // ─── AUTO-SLIDE ─────────────────────────────────────────────────
  // Tweak these three to change the pacing/feel — nothing else below
  // needs to change.
  //   - interval: how long each slide stays on screen before advancing.
  //   - animationDuration: how long the slide-to-slide transition takes.
  //   - curve: easing for that transition.
  static const _autoSlideInterval = Duration(seconds: 4);
  static const _autoSlideAnimationDuration = Duration(milliseconds: 500);
  static const _autoSlideCurve = Curves.easeInOut;

  Timer? _autoSlideTimer;

  // ─── ADMIN NOTIFICATIONS PANEL (14.09.2026) ───────────────────────
  // Whether the collapsible admin notifications panel (see
  // _buildAdminNotificationsPanel) is currently expanded. Starts
  // collapsed so an admin with several pending items sees one compact
  // summary row instead of the homepage being immediately filled with
  // banners before they've even reached the quick-access grid.
  bool _notificationsExpanded = false;

  // (Re)starts the countdown to the next auto-advance. Called once on
  // init, and again every time the page changes (manual swipe or
  // auto-advance) so a manual swipe always gets a full fresh interval
  // instead of being cut short by whatever was left on the previous
  // countdown.
  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (_bannerImages.length <= 1) return; // nothing to slide between
    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!_bannerController.hasClients) return;
      _bannerController.nextPage(
        duration: _autoSlideAnimationDuration,
        curve: _autoSlideCurve,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _currentBanner = _loopInitialPage;
    _startAutoSlide();
    // Guard: HomePage is reachable directly by route name, so if there's
    // no active session (hot restart mid-session, deep link, etc.) bounce
    // straight back to Login instead of rendering with a null user.
    if (!AuthService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      });
    } else {
      // BUG FIX (14.09.2026): AdminRequestService's cache is only ever
      // populated by an explicit refresh() call — main.dart only makes
      // that call on a cold start with a *restored* session, so a fresh
      // login (or just navigating back to HomePage mid-session) never
      // triggered it. The Admin notifications panel would then show
      // stale/empty data until the user knew to pull-to-refresh
      // manually. Firing a refresh every time HomePage is entered means
      // it's correct immediately instead of requiring that extra step.
      _refreshHomeDataSilently();
    }
  }

  // Same non-fatal error handling as main.dart's startup refresh: if
  // this fails (offline, dropped connection), HomePage just keeps
  // showing whatever was already cached instead of throwing mid-initState.
  Future<void> _refreshHomeDataSilently() async {
    try {
      await PeminjamanService.refresh();
      await AdminRequestService.refresh();
    } catch (_) {
      // Non-fatal — see comment above.
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
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
      await AdminRequestService.refresh();
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
        _navigateAndRefresh(AppRoutes.returnPage);
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
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusHeader),
        ),
        boxShadow: AppTheme.headerShadow,
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
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
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
    // Solid, distinct colour per action + white icon — the old 12%-tint
    // circles blended into the white card (and the grey-green primary
    // made them read as plain grey).
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.edit_document,
        'label': 'Form\nPeminjaman',
        'color': AppTheme.primaryGreen,
        'route': AppRoutes.form,
      },
      {
        'icon': Icons.inventory_2_rounded,
        'label': 'Inventaris\nArsip',
        'color': AppTheme.infoBlue,
        'route': AppRoutes.archive,
      },
      {
        'icon': Icons.list_alt_rounded,
        'label': 'Daftar\nPeminjaman',
        'color': AppTheme.accentGreen,
        'route': AppRoutes.history,
      },
      {
        'icon': Icons.assignment_return_rounded,
        'label': 'Pengem-\nbalian',
        'color': AppTheme.actionOrange,
        'route': AppRoutes.returnPage,
      },
      {
        'icon': Icons.qr_code_scanner_rounded,
        'label': 'Scan QR\nCode',
        'color': AppTheme.infoPurple,
        'route': AppRoutes.scan,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.elevationSurface,
        ),
        child: Row(
          children: items.map((item) {
            final color = item['color'] as Color;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navigateAndRefresh(item['route'] as String),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        // Soft tint of the accent + accent-colored icon,
                        // instead of a solid circle with a colored halo.
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
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
                onPageChanged: (i) {
                  setState(() => _currentBanner = i);
                  _startAutoSlide();
                },
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
                                    Colors.black.withValues(alpha: 0.55),
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
            color: AppTheme.gold,
          ),
          JenisDokumenStat(
            jenis: 'Warkah',
            icon: Icons.folder_copy_outlined,
            count: PeminjamanService.getCountWarkah(),
            color: AppTheme.infoPurple,
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
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              boxShadow: AppTheme.elevationSurface,
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
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
            color: AppTheme.warningAmber,
            value: aktif.toString(),
            label: 'Sedang\nDipinjam',
            onTap: () => _navigateAndRefresh(AppRoutes.returnPage),
          ),
          chip(
            icon: Icons.inventory_2_outlined,
            color: AppTheme.successGreen,
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

  Color _homeStatusColor(Peminjaman p) {
    if (p.status == 'Diajukan') return AppTheme.pendingAmber;
    if (p.status == 'Ditolak') return AppTheme.dangerRed;
    if (p.status == 'Dipinjam') {
      return p.isOverdue ? AppTheme.dangerRed : AppTheme.warningAmber;
    }
    return AppTheme.successGreen;
  }

  Color _homeStatusBg(Peminjaman p) {
    if (p.status == 'Diajukan') return AppTheme.warningBg;
    if (p.status == 'Ditolak') return AppTheme.dangerBg;
    if (p.status == 'Dipinjam') {
      return p.isOverdue ? AppTheme.dangerBg : AppTheme.warningBg;
    }
    return AppTheme.successBg;
  }

  String _homeStatusLabel(Peminjaman p) {
    if (p.status == 'Diajukan') return 'Menunggu';
    if (p.status == 'Ditolak') return 'Ditolak';
    if (p.status == 'Dipinjam') return p.isOverdue ? 'Terlambat' : 'Dipinjam';
    return 'Kembali';
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
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.barcode,
                    arguments: {
                      'id': p.id ?? '',
                      'noHak': p.noHak,
                      'nama': p.nama,
                      'seksi': p.seksi,
                      'kelurahan': p.kelurahan,
                      'jenisHak': p.jenisHak,
                      'jenisDokumen': p.jenisDokumen,
                      'tanggalPinjam': p.tanggalPinjamFormatted,
                      'tanggalKembali': p.tanggalKembaliFormatted,
                      // ── Surat Ukur–specific ──
                      'jenisSuratUkur': p.jenisSuratUkur ?? '',
                      'noTahunSuratUkur': p.noTahunSuratUkur ?? '',
                      'su': p.su ?? '',
                      'gs': p.gs ?? '',
                      // ── Warkah–specific ──
                      'jenisWarkah': p.jenisWarkah ?? '',
                      'no208': p.no208 ?? '',
                      'tahunWarkah': p.tahunWarkah ?? '',
                    },
                  ),
                  child: Container(
                    width: 190,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      boxShadow: AppTheme.elevationSurface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _dokumenTypeLabel(p),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
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
                                color: _homeStatusBg(p),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _homeStatusLabel(p),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _homeStatusColor(p),
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
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.elevationSurface,
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

  // ─── SHARED NOTIFICATION ROW ────────────────────────────────────
  // One notification row's visuals — white card, soft shadow, icon in
  // a rounded color chip, chevron in a muted circle. No outer margin
  // of its own: callers decide spacing, because this is now used both
  // stand-alone (Pegawai's overdue banner) and stacked inside the
  // collapsible admin panel below, which need different surrounding
  // padding.
  //
  // [urgent] is for the one notification that should visually outrank
  // the rest at a glance (the Admin role request) — a thin colored
  // ring plus a solid-filled icon chip (white icon on accentColor)
  // instead of the soft tint the others use.
  // ─── SHARED NOTIFICATION ROW ────────────────────────────────────
  // One notification row's visuals — soft shadow, icon in a rounded
  // color chip, chevron on the right. No outer margin of its own:
  // callers decide spacing, because this is used both stand-alone
  // (Pegawai's overdue banner) and stacked inside the collapsible
  // admin panel, which need different surrounding padding.
  //
  // [flat] switches between the two contexts:
  //   - false (default): standalone card sitting on the page
  //     background. Keeps the tinted fill + shadow, because that's
  //     what lifts it off AppTheme.background.
  //   - true: a row nested inside the admin panel. Plain white fill,
  //     no shadow — the panel's tinted body provides the contrast,
  //     and four stacked blurred cards would otherwise just paint a
  //     grey halo over each other.
  //
  // [urgent] is for the one notification that should outrank the rest
  // at a glance (the Admin role request) — a thin colored ring plus a
  // solid-filled icon chip (white icon on accentColor) instead of the
  // soft tint the others use.
  Widget _buildNotifCard({
    required IconData icon,
    required Color accentColor,
    required Color accentBg,
    required String message,
    required VoidCallback onTap,
    bool urgent = false,
    bool flat = false,
  }) {
    // One accent-tinted hairline. Urgent rows get a slightly stronger
    // line; everything else stays quiet so the icon carries the color,
    // not the entire card.
    final borderColor = flat
        ? (urgent
              ? accentColor.withValues(alpha: 0.45)
              : AppTheme.divider.withValues(alpha: 0.9))
        : accentColor.withValues(alpha: urgent ? 0.55 : 0.25);

    return Material(
      // Nested rows sit on the panel's tinted body, so they're plain
      // white. The old always-tinted fill was the main culprit: at
      // alpha 0.45 over white, AppTheme.dangerBg/successBg/warningBg
      // all land within a few RGB points of white, so the cards were
      // effectively invisible against the white panel behind them.
      color: flat
          ? Colors.white
          : Color.alphaBlend(accentBg.withValues(alpha: 0.45), Colors.white),
      borderRadius: BorderRadius.circular(flat ? 14 : 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(flat ? 14 : 18),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(flat ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(flat ? 14 : 18),
            border: Border.all(color: borderColor, width: urgent ? 1.4 : 1),
            // Shadow only when this row is standing on its own.
            boxShadow: flat
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: flat ? 38 : 42,
                height: flat ? 38 : 42,
                decoration: BoxDecoration(
                  color: urgent ? accentColor : accentBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: urgent ? Colors.white : accentColor,
                  size: flat ? 19 : 21,
                ),
              ),
              SizedBox(width: flat ? 12 : 13),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: flat ? 12.5 : 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: urgent ? accentColor : AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Was a chevron inside a white circle — invisible once
              // the card itself became white, so it's a plain muted
              // glyph now.
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: flat ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ADMIN NOTIFICATIONS: DATA COLLECTION (14.09.2026 redesign) ───
  // Gathers every pending admin notification (role requests, overdue
  // documents, loan requests, extension requests) into one flat list
  // instead of each having its own always-visible banner. The Admin
  // role request is always first and always [urgent] — it's a
  // standing-access decision, not a per-document one, so it should
  // never get buried the way it did visually in the previous revision.
  List<_NotifItem> _collectAdminNotifItems() {
    final items = <_NotifItem>[];

    final adminRequests = AdminRequestService.getPending();
    if (adminRequests.isNotEmpty) {
      items.add(
        _NotifItem(
          icon: Icons.admin_panel_settings_rounded,
          color: AppTheme.dangerRed,
          bg: AppTheme.dangerBg,
          message: adminRequests.length == 1
              ? '1 permintaan menjadi Admin menunggu persetujuan Anda.'
              : '${adminRequests.length} permintaan menjadi Admin menunggu persetujuan Anda.',
          onTap: _showAdminRoleRequestSheet,
          urgent: true,
        ),
      );
    }

    final overdue = PeminjamanService.getTerlambat();
    if (overdue > 0) {
      items.add(
        _NotifItem(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.dangerRed,
          bg: AppTheme.dangerBg,
          message: '$overdue dokumen sudah lewat batas waktu pengembalian.',
          onTap: _showOverdueSheet,
        ),
      );
    }

    final loanRequests = PeminjamanService.getPengajuanPeminjaman();
    if (loanRequests.isNotEmpty) {
      items.add(
        _NotifItem(
          icon: Icons.note_add_rounded,
          color: AppTheme.successGreen,
          bg: AppTheme.successBg,
          message:
              '${loanRequests.length} pengajuan peminjaman baru menunggu persetujuan Anda.',
          onTap: _showLoanApprovalSheet,
        ),
      );
    }

    final extensions = PeminjamanService.getPengajuanPerpanjangan();
    if (extensions.isNotEmpty) {
      items.add(
        _NotifItem(
          icon: Icons.pending_actions_rounded,
          color: AppTheme.warningAmber,
          bg: AppTheme.warningBg,
          message:
              '${extensions.length} pengajuan perpanjangan menunggu persetujuan Anda.',
          onTap: _showExtensionApprovalSheet,
        ),
      );
    }

    return items;
  }

  // ─── ADMIN NOTIFICATIONS: COLLAPSIBLE PANEL (14.09.2026 redesign) ──
  // Previously each of the four admin notifications was its own
  // always-visible banner, so an admin with several pending items had
  // the homepage filled with stacked cards before ever reaching the
  // quick-access grid. This collapses them into one summary row —
  // "N hal butuh perhatian Anda" — that expands in place on tap
  // instead of pushing to a separate screen, so the full list is one
  // tap away without permanently eating vertical space.
  Widget _buildAdminNotificationsPanel() {
    if (!AuthService.isAdmin) return const SizedBox.shrink();

    final items = _collectAdminNotifItems();
    if (items.isEmpty) return const SizedBox.shrink();

    final hasUrgent = items.any((i) => i.urgent);
    final headerColor = hasUrgent ? AppTheme.dangerRed : AppTheme.primaryGreen;
    final headerBg = hasUrgent ? AppTheme.dangerBg : AppTheme.successBg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          // Was a full-strength red outline whenever anything was
          // urgent — which drew a second red rectangle directly
          // inside the urgent card's own red outline, and a third
          // around the overdue row. Urgency is carried by the header
          // chip and the single urgent row, so there's one red accent
          // instead of three; the panel itself is separated by elevation.
          boxShadow: AppTheme.elevationRaised,
        ),
        // So the tinted body below respects the 18px corners instead
        // of squaring them off.
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(
                  () => _notificationsExpanded = !_notificationsExpanded,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: headerBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: headerColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${items.length} hal butuh perhatian Anda',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _notificationsExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _notificationsExpanded
                    ? Container(
                        width: double.infinity,
                        // Tinted body — this is the single change that
                        // stops panel fill, card fill, and card border
                        // from all collapsing into the same white. The
                        // white rows below now have something to sit on.
                        color: AppTheme.surfaceMuted,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                                child: _buildNotifCard(
                                  icon: items[i].icon,
                                  accentColor: items[i].color,
                                  accentBg: items[i].bg,
                                  message: items[i].message,
                                  onTap: items[i].onTap,
                                  urgent: items[i].urgent,
                                  flat: true,
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
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
  // ringkasan pribadi. Pegawai only ever has this one notification, so
  // it stays a plain always-visible card rather than going through the
  // collapsible panel (which is Admin-only, see above).
  Widget _buildPegawaiOverdueBanner() {
    if (!AuthService.isPegawai) return const SizedBox.shrink();

    final belumKembali = PeminjamanService.getBelumKembaliBrp();
    if (belumKembali == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _buildNotifCard(
        icon: Icons.warning_amber_rounded,
        accentColor: AppTheme.dangerRed,
        accentBg: AppTheme.dangerBg,
        message:
            '$belumKembali dokumen Anda sudah lewat batas waktu pengembalian.',
        onTap: () => _navigateAndRefresh(AppRoutes.returnPage),
      ),
    );
  }

  // ─── Item 4: bottom sheet approval perpanjangan untuk Admin. Dibuka dari
  // banner di atas maupun dari bell notifikasi. Pakai StatefulBuilder biar
  // list-nya bisa refresh sendiri setelah Setujui/Tolak tanpa nutup sheet.
  // ─── Approval pengajuan peminjaman baru (11.08.2026) — mirror persis
  // _showExtensionApprovalSheet di bawah. Beda utamanya: di-key pakai
  // `p.id` (bukan noHak — Warkah semuanya share noHak = '-', jadi noHak
  // nggak unik buat beberapa pengajuan Warkah sekaligus), dan info yang
  // ditampilin per baris (jenis dokumen + keperluan) bukan tanggal
  // perpanjangan.
  //
  // ─── UPDATED: PeminjamanService.setujuiPeminjaman/tolakPeminjaman now
  // require a real 3-item checklist / a real rejection reason instead of
  // taking just an id (see peminjaman_service.dart's doc comments on
  // those two methods). `_decide` below now accepts those values instead
  // of calling the service bare, and Setujui/Tolak each open a small
  // dialog first — _confirmApprove()/_confirmReject() — so the admin is
  // actually asked for the checklist/reason instead of it being silently
  // hardcoded to true / a canned string, which would defeat the entire
  // point of the service-side gate.
  // ─── ADMIN ROLE REQUEST sheet — mirrors _showLoanApprovalSheet's
  // shape (StatefulBuilder, try/catch around the service call, SnackBar
  // feedback, auto-close when the last item resolves) but simpler: no
  // physical-document checklist gate, since granting Admin isn't tied to
  // a physical object like a loan approval is.
  void _showAdminRoleRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // Persists across setSheetState rebuilds (created once when the
        // sheet opens, not per-rebuild) — tracks which request ids are
        // mid-network-call so their buttons can show a spinner and
        // reject double-taps instead of silently looking unresponsive.
        final processingIds = <String>{};

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final pending = AdminRequestService.getPending();

            Future<void> decide(AdminRequest request, bool approve) async {
              // Ignore a second tap while the first is still in flight.
              if (processingIds.contains(request.id)) return;
              setSheetState(() => processingIds.add(request.id));

              String? error;
              try {
                error = approve
                    ? await AdminRequestService.approve(request)
                    : await AdminRequestService.reject(request);
              } catch (e) {
                // Defensive belt-and-suspenders: AdminRequestService
                // already catches internally and returns a message
                // string, but if anything unexpected slips through
                // uncaught, surface it instead of leaving the button
                // stuck spinning forever with no explanation.
                error = 'Terjadi kesalahan tak terduga: $e';
              }

              if (!mounted) return;
              setSheetState(() => processingIds.remove(request.id));

              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: AppTheme.dangerRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              setSheetState(() {});
              setState(() {}); // refresh badge + banner di HomePage
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approve
                        ? '${request.nama} disetujui menjadi Admin.'
                        : 'Permintaan ${request.nama} ditolak.',
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

            Future<void> confirmReject(AdminRequest request) async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Tolak permintaan Admin?'),
                  content: Text(
                    '${request.nama} tidak akan menjadi Admin. Mereka bisa '
                    'mengajukan lagi nanti.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                      ),
                      child: const Text('Tolak'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await decide(request, false);
            }

            // ─── RESTYLE (14.09.2026): dropped the solid dangerBg fill +
            // icon-header layout this sheet used to have — it read as a
            // different design language from every other approval sheet
            // (Pengajuan Peminjaman / Pengajuan Perpanjangan), which use
            // a plain white background, bold title + gray subtitle line,
            // and untinted list rows separated by a Divider. Mirrors that
            // exact structure now so all three approval sheets feel like
            // the same app instead of one standing out as "the red one".
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
                    'Permintaan Admin',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pending.length} permintaan menunggu keputusan.',
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
                          'Tidak ada permintaan yang menunggu.',
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
                          final request = pending[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${request.nama} — ${request.jabatan}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Alasan:',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (request.alasan == null ||
                                        request.alasan!.isEmpty)
                                    ? 'Tidak ada alasan yang dicantumkan.'
                                    : request.alasan!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Builder(
                                builder: (context) {
                                  final isProcessing = processingIds.contains(
                                    request.id,
                                  );
                                  const spinner = SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  );
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: isProcessing
                                              ? null
                                              : () => confirmReject(request),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.dangerRed,
                                            side: const BorderSide(
                                              color: AppTheme.dangerRed,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                          child: isProcessing
                                              ? spinner
                                              : const Text('Tolak'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: isProcessing
                                              ? null
                                              : () => decide(request, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.accentGreen,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                          child: isProcessing
                                              ? const SizedBox(
                                                  height: 16,
                                                  width: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : const Text(
                                                  'Setujui',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
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

  void _showLoanApprovalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final pending = PeminjamanService.getPengajuanPeminjaman();

            Future<void> decide(
              String id,
              bool approve, {
              bool checklistDokumenDitemukan = false,
              bool checklistKondisiBaik = false,
              bool checklistSesuaiData = false,
              String alasan = '',
            }) async {
              // FIX: this used to have no try/catch at all. Both
              // setujuiPeminjaman/tolakPeminjaman can throw (RLS
              // rejection, missing column, dropped connection, etc.) —
              // an uncaught throw here just vanishes into the void from
              // an onPressed callback: no SnackBar, no setState, nothing
              // visible, even though something real went wrong. Now the
              // error message actually reaches the admin instead of only
              // ever showing up (if at all) in a debug console nobody's
              // watching.
              bool ok;
              try {
                ok = approve
                    ? await PeminjamanService.setujuiPeminjaman(
                        id,
                        checklistDokumenDitemukan: checklistDokumenDitemukan,
                        checklistKondisiBaik: checklistKondisiBaik,
                        checklistSesuaiData: checklistSesuaiData,
                      )
                    : await PeminjamanService.tolakPeminjaman(id, alasan);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal memproses pengajuan: $e'),
                    backgroundColor: AppTheme.dangerRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (!mounted) return;
              if (!ok) {
                // FIX: this used to just `return` here — the service
                // legitimately returns false (not an exception) when the
                // update matches 0 rows, e.g. an RLS policy silently
                // blocked it, or someone else already decided this
                // request. That's a real failure the admin needs to
                // see, not something to swallow quietly.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      approve
                          ? 'Gagal menyetujui — pengajuan mungkin sudah '
                                'diproses, atau Anda tidak punya izin.'
                          : 'Gagal menolak — pengajuan mungkin sudah '
                                'diproses, atau Anda tidak punya izin.',
                    ),
                    backgroundColor: AppTheme.dangerRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              setSheetState(() {});
              setState(() {}); // refresh badge + banner di HomePage
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approve
                        ? 'Pengajuan peminjaman disetujui.'
                        : 'Pengajuan peminjaman ditolak.',
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

            // Checklist dokumen fisik (3 item, semua wajib dicentang)
            // sebelum admin bisa menyetujui pengajuan — mirror gate yang
            // sama di PeminjamanService.setujuiPeminjaman.
            Future<void> confirmApprove(String id) async {
              bool dokumen = false;
              bool kondisi = false;
              bool sesuai = false;

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return StatefulBuilder(
                    builder: (dialogContext, setDialogState) {
                      final semuaTercentang = dokumen && kondisi && sesuai;
                      return AlertDialog(
                        title: const Text('Checklist Dokumen Fisik'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pastikan ketiga hal berikut sudah diperiksa '
                              'sebelum menyetujui pengajuan ini:',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: dokumen,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Dokumen ditemukan'),
                              onChanged: (v) =>
                                  setDialogState(() => dokumen = v ?? false),
                            ),
                            CheckboxListTile(
                              value: kondisi,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Kondisi dokumen baik'),
                              onChanged: (v) =>
                                  setDialogState(() => kondisi = v ?? false),
                            ),
                            CheckboxListTile(
                              value: sesuai,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Sesuai data pengajuan'),
                              onChanged: (v) =>
                                  setDialogState(() => sesuai = v ?? false),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGreen,
                            ),
                            onPressed: semuaTercentang
                                ? () => Navigator.pop(dialogContext, true)
                                : null,
                            child: const Text(
                              'Setujui',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );

              if (confirmed == true) {
                await decide(
                  id,
                  true,
                  checklistDokumenDitemukan: dokumen,
                  checklistKondisiBaik: kondisi,
                  checklistSesuaiData: sesuai,
                );
              }
            }

            // Alasan penolakan (wajib diisi) sebelum admin bisa menolak
            // pengajuan — mirror parameter wajib `alasan` di
            // PeminjamanService.tolakPeminjaman.
            Future<void> confirmReject(String id) async {
              final controller = TextEditingController();

              final alasan = await showDialog<String>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Alasan Penolakan'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Tulis alasan penolakan...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerRed,
                        ),
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          Navigator.pop(dialogContext, text);
                        },
                        child: const Text(
                          'Tolak',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (alasan != null && alasan.isNotEmpty) {
                await decide(id, false, alasan: alasan);
              }
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
                    'Pengajuan Peminjaman',
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
                                '${p.nama} — ${p.jenisDokumen}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dokumenIdentifier(p),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                'Rencana: ${p.tanggalPinjamFormatted} — ${p.tanggalKembaliFormatted}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              if (p.keperluan.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Keperluan: ${p.keperluan}',
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
                                      onPressed: () => confirmReject(p.id!),
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
                                      onPressed: () => confirmApprove(p.id!),
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

  void _showExtensionApprovalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final pending = PeminjamanService.getPengajuanPerpanjangan();

            // BUG FIX: setujuiPerpanjangan/tolakPerpanjangan look the loan
            // up by `id` (see _findActiveById), but the callers below used
            // to pass `p.noHak` — which never matches, so approve/reject
            // silently did nothing. Now takes the real `id`, plus a
            // separate `label` just for display in the snackbar (showing
            // the raw id there would be meaningless to the user).
            Future<void> decide(String id, String label, bool approve) async {
              final ok = approve
                  ? await PeminjamanService.setujuiPerpanjangan(id)
                  : await PeminjamanService.tolakPerpanjangan(id);
              if (!ok) return;
              if (!mounted) return;
              setSheetState(() {});
              setState(() {}); // refresh badge + banner di HomePage
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approve
                        ? 'Perpanjangan $label disetujui.'
                        : 'Perpanjangan $label ditolak.',
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
                                      onPressed: () =>
                                          decide(p.id!, p.noHak, false),
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
                                      onPressed: () =>
                                          decide(p.id!, p.noHak, true),
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

  // ─── BUG FIX: tapping the admin overdue banner used to just navigate
  // to ReturnPage — inconsistent with the loan-request/extension banners
  // above, which open a sheet listing exactly what's pending right from
  // the homepage. Mirrors those two sheets: lists every overdue document
  // (admin scope — see getOverdueForNotifikasi), most overdue first, with
  // a "Proses Kembali" action per row so returning one doesn't require
  // leaving the sheet.
  void _showOverdueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final overdue = PeminjamanService.getOverdueForNotifikasi();

            Future<void> prosesKembali(Peminjaman p) async {
              bool ok = false;
              try {
                ok = await PeminjamanService.kembalikan(p.id!);
              } catch (_) {
                ok = false;
              }
              if (!mounted) return;
              setSheetState(() {});
              setState(() {}); // refresh badge + banner di HomePage
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '${_dokumenIdentifier(p)} berhasil dikembalikan.'
                        : 'Gagal mengembalikan dokumen.',
                  ),
                  backgroundColor: ok
                      ? AppTheme.accentGreen
                      : AppTheme.dangerRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              if (overdue.length <= 1) Navigator.pop(sheetContext);
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
                    'Dokumen Terlambat Dikembalikan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${overdue.length} dokumen sudah lewat batas waktu.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (overdue.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Tidak ada dokumen yang terlambat.',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: overdue.length,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          final p = overdue[index];
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
                                'Batas pengembalian: ${p.tanggalKembaliFormatted}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                'Terlambat ${p.hariTerlambat} hari',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.dangerRed,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => prosesKembali(p),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentGreen,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    'Proses Kembali',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
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
              _buildAdminNotificationsPanel(),
              _buildPegawaiOverdueBanner(),
              _buildPersonalSummary(),
              const SizedBox(height: 10),
              _buildQuickAccessGrid(),
              const SizedBox(height: 22),
              _buildImageCarousel(),
              const SizedBox(height: 20),
              _buildJenisDokumenBreakdown(),
              const SizedBox(height: 24),
              _buildStatChips(),
              const SizedBox(height: 14),
              _buildRecentActivity(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
