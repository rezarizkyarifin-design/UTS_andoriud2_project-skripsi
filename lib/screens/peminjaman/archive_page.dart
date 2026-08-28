import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_scan_fab.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  int _selectedNavIndex = 1; // Arsip aktif di index 1
  bool _isLoading = true;
  // BUG FIX: a failed fetch used to leave both of these empty with
  // _isLoading flipped to false — indistinguishable from "loaded fine,
  // genuinely nothing here." _loadError separates the two so the UI
  // can show a real retry banner instead of a misleading "not found".
  String? _loadError;
  List<Map<String, dynamic>> _arsipList = [];
  List<Map<String, dynamic>> _filteredList = [];
  final TextEditingController _searchController = TextEditingController();

  // Persistent filter chips (Semua/Buku Tanah/Surat Ukur/Warkah) — every
  // other list page in the app (History's status chips) has a filter
  // row like this; Archive had none despite three obvious buckets.
  String? _selectedJenis; // null = Semua

  static const _jenisColors = {
    'Buku Tanah': AppTheme.primaryGreen,
    'Surat Ukur': Color(0xFFC08A3E), // same gold used elsewhere in the app
    'Warkah': Color(0xFF5B7FDB),
  };

  @override
  void initState() {
    super.initState();
    _fetchMasterArsip();
    _searchController.addListener(_filterSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalDokumen => _arsipList.length;
  int _countJenis(String jenis) =>
      _arsipList.where((a) => a['jenis_dokumen'] == jenis).length;

  Future<void> _fetchMasterArsip() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final data = await Supabase.instance.client
          .from('master_arsip')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _arsipList = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
      _filterSearch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  // BUG FIX: was building the haystack with plain string interpolation
  // ('${arsip['no_hak']}'), which turns a null field into the literal
  // text "null" — every Warkah's no_hak, every Buku Tanah's no_208, etc.
  // are all null, so searching for "null" matched a huge chunk of the
  // inventory. `?? ''` keeps a missing field from ever being searchable
  // text at all.
  void _filterSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredList = _arsipList.where((arsip) {
        if (_selectedJenis != null &&
            arsip['jenis_dokumen'] != _selectedJenis) {
          return false;
        }
        if (query.isEmpty) return true;
        final haystack = [
          arsip['jenis_dokumen'],
          arsip['no_hak'],
          arsip['kelurahan'],
          arsip['no_208'],
          arsip['jenis_hak'],
          arsip['jenis_warkah'],
          arsip['jenis_surat_ukur'],
        ].map((v) => (v ?? '').toString()).join(' ').toLowerCase();
        return haystack.contains(query);
      }).toList();
    });
  }

  void _onNavTap(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case 1:
        // Already here
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.history);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.returnPage);
        break;
    }
  }

  void _onDrawerNavigate(String route) {
    if (route == AppRoutes.archive) return;
    Navigator.pushReplacementNamed(context, route);
  }

  Widget _buildItem(Map<String, dynamic> arsip) {
    final jenis = arsip['jenis_dokumen'] ?? 'Buku Tanah';
    String title = '';
    String subtitle = '';
    IconData icon = Icons.description;
    final accent = _jenisColors[jenis] ?? AppTheme.primaryGreen;

    if (jenis == 'Buku Tanah') {
      icon = Icons.menu_book_outlined;
      title = '${arsip['jenis_hak'] ?? '-'} - ${arsip['no_hak'] ?? '-'}';
      subtitle =
          'Kec. ${arsip['kecamatan'] ?? '-'}, Kel. ${arsip['kelurahan'] ?? '-'}';
    } else if (jenis == 'Warkah') {
      icon = Icons.folder_copy_outlined;
      title = 'Warkah: ${arsip['jenis_warkah'] ?? '-'}';
      subtitle =
          'No. 208: ${arsip['no_208'] ?? '-'} (${arsip['tahun_warkah'] ?? '-'})';
    } else if (jenis == 'Surat Ukur') {
      icon = Icons.straighten_outlined;
      title = 'SU: ${arsip['su'] ?? '-'} / GS: ${arsip['gs'] ?? '-'}';
      subtitle =
          '${arsip['jenis_surat_ukur'] ?? '-'} (${arsip['no_tahun_surat_ukur'] ?? '-'})';
    }

    // Left-edge color accent bar — matches History/Return's status-colored
    // card border, so Archive's cards read as part of the same family
    // instead of a plain generic ListTile.
    // BUG FIX: BoxDecoration.border only draws a rounded stroke when all
    // four sides are uniform — a single-sided Border(left: ...) like this
    // one is painted as a plain straight line regardless of borderRadius,
    // which is why it looked like it was cutting across the rounded
    // corners instead of following them. Wrapping the whole card in
    // ClipRRect clips that straight line (and everything else) to the
    // rounded rect shape, so the accent bar actually curves with the card.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: accent, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: accent.withOpacity(0.12),
            child: Icon(icon, color: accent),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              jenis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBox({
    required IconData icon,
    required int count,
    required String label,
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jenisChip(String label, String? value) {
    final selected = _selectedJenis == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedJenis = value);
          _filterSearch();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryGreen : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // BUG FIX: this page never had a `drawer:` at all, even though
      // AppTopBar's hamburger icon calls Scaffold.of(context).openDrawer()
      // unconditionally — tapping it here did nothing. AppDrawer also
      // needed a new DrawerSection.archive value (see app_drawer.dart)
      // since Archive wasn't in its nav list either.
      drawer: AppDrawer(
        active: DrawerSection.archive,
        onNavigate: _onDrawerNavigate,
      ),
      bottomNavigationBar: AppBottomNav(
        activeIndex: _selectedNavIndex,
        onItemSelected: _onNavTap,
      ),
      // BUG FIX: every other main page (Home/History/Return) has this
      // centrally-docked scan button; Archive never had it wired up at
      // all, which is why the bottom nav notch here sat empty instead
      // of showing the green scan FAB.
      floatingActionButton: AppScanFab(
        onTap: () => Navigator.pushNamed(context, AppRoutes.scan),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Column(
        children: [
          // Header + floating search card — same overlapping-seam pattern
          // as Home/History/Return, instead of a flush-in-header TextField
          // with the non-standard InputDecoration.icon (which is what made
          // this bar look and sit differently from every other page).
          // BUG FIX: this used to be a plain Container with the search
          // card Positioned at bottom: 0 of a Stack sized to that same
          // Container — so the card's bottom edge landed exactly on the
          // header's bottom edge, meaning the whole card sat inside the
          // green area instead of overlapping the seam. Same reserved-
          // spacer technique as History/Return: a trailing SizedBox
          // inside the sizing Column gives the Stack extra height for
          // the card to hang down into, so it actually straddles the
          // boundary.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryGreen, AppTheme.accentGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          const AppTopBar(title: 'Inventaris Arsip'),
                          const SizedBox(height: 18),
                          // Stats row — Archive had no overview summary
                          // at all before, unlike every comparable list
                          // page (History's Total Berkas/Sedang
                          // Dipinjam/... row).
                          Row(
                            children: [
                              _statBox(
                                icon: Icons.inventory_2_outlined,
                                count: _totalDokumen,
                                label: 'Total\nDokumen',
                              ),
                              _statBox(
                                icon: Icons.menu_book_outlined,
                                count: _countJenis('Buku Tanah'),
                                label: 'Buku\nTanah',
                              ),
                              _statBox(
                                icon: Icons.straighten_outlined,
                                count: _countJenis('Surat Ukur'),
                                label: 'Surat\nUkur',
                              ),
                              _statBox(
                                icon: Icons.folder_copy_outlined,
                                count: _countJenis('Warkah'),
                                label: 'Warkah',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Cari nomor hak, warkah, kelurahan...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.black38),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.black38,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _jenisChip('Semua', null),
                  _jenisChip('Buku Tanah', 'Buku Tanah'),
                  _jenisChip('Surat Ukur', 'Surat Ukur'),
                  _jenisChip('Warkah', 'Warkah'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Gagal memuat arsip',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _fetchMasterArsip,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _filteredList.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada dokumen arsip ditemukan.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchMasterArsip,
                    color: AppTheme.accentGreen,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) =>
                          _buildItem(_filteredList[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
