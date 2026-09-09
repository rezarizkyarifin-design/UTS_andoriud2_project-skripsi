import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/data.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/peminjaman_service.dart';
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
  final int _selectedNavIndex = 1; // Arsip aktif di index 1
  bool _isLoading = true;
  // BUG FIX: a failed fetch used to leave both of these empty with
  // _isLoading flipped to false — indistinguishable from "loaded fine,
  // genuinely nothing here." _loadError separates the two so the UI
  // can show a real retry banner instead of a misleading "not found".
  String? _loadError;
  List<Map<String, dynamic>> _arsipList = [];
  List<Map<String, dynamic>> _filteredList = [];

  // BUG FIX: the header stat row (Total Dokumen/Buku Tanah/Surat
  // Ukur/Warkah) reads straight off _arsipList, which used to start as
  // an empty list every time this page was built — so on every visit
  // the stats painted "0" for one frame before the Supabase fetch in
  // _fetchMasterArsip() resolved and repainted with the real counts.
  // History/Return don't have this flash because their data comes from
  // PeminjamanService, a static cache seeded synchronously in initState
  // before the first frame. This mirrors that: a static cache that
  // survives across visits to this page within the app session, seeded
  // into _arsipList before anything is built, then kept fresh below.
  static List<Map<String, dynamic>> _cachedArsipList = [];
  final TextEditingController _searchController = TextEditingController();

  // Persistent filter chips (Semua/Buku Tanah/Surat Ukur/Warkah) — every
  // other list page in the app (History's status chips) has a filter
  // row like this; Archive had none despite three obvious buckets.
  String? _selectedJenis; // null = Semua
  static const Color _accentGreen = AppTheme.accentGreen;
  static const _jenisColors = {
    'Buku Tanah': AppTheme.primaryGreen,
    'Surat Ukur': AppTheme.warningAmber,
    'Warkah': Color(0xFF5C5FCD),
  };

  @override
  void initState() {
    super.initState();
    // Show whatever's cached immediately so the stats/list aren't blank
    // (or briefly "0") while the network fetch below is in flight.
    // (Assigned directly rather than via _filterSearch() — search text
    // and the jenis filter both start empty, so this is equivalent, and
    // it avoids calling setState() ahead of the first build.)
    _arsipList = List<Map<String, dynamic>>.from(_cachedArsipList);
    _filteredList = List<Map<String, dynamic>>.from(_arsipList);
    _fetchMasterArsip();
    _searchController.addListener(_filterSearch);
    // Archive previously never touched PeminjamanService at all, so
    // findActiveLoanForArsip() (used below and in _showArchiveDetail)
    // would silently see an empty cache on a cold start — e.g. Archive
    // opened as the very first page after login, before Home/History
    // ever got a chance to populate it. This refresh is fire-and-forget:
    // the page still renders immediately from whatever's cached, and
    // just repaints once real loan data lands.
    PeminjamanService.refresh()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          // Non-fatal: availability just falls back to "unknown loan data",
          // same as if this page had never called refresh() at all.
        });
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
      _cachedArsipList = List<Map<String, dynamic>>.from(data);
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

  Future<void> _showAddArchiveSheet() async {
    if (!AuthService.isAdmin) return;

    final noHakController = TextEditingController();
    final noTahunController = TextEditingController();
    final suController = TextEditingController();
    final gsController = TextEditingController();
    final no208Controller = TextEditingController();
    final tahunWarkahController = TextEditingController();
    String jenisDokumen = 'Buku Tanah';
    String? jenisHak;
    String? jenisSuratUkur;
    String? jenisWarkah;
    String? kecamatan;
    String? kelurahan;
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final kelurahanOptions = kecamatan == null
                ? const <String>[]
                : (Data.kelurahan[kecamatan] ?? const <String>[]);

            Future<void> save() async {
              final identifier = jenisDokumen == 'Warkah'
                  ? no208Controller.text.trim()
                  : noHakController.text.trim();
              if (identifier.isEmpty ||
                  (jenisDokumen == 'Buku Tanah' &&
                      (jenisHak == null ||
                          kecamatan == null ||
                          kelurahan == null)) ||
                  (jenisDokumen == 'Surat Ukur' &&
                      (jenisSuratUkur == null ||
                          noTahunController.text.trim().isEmpty ||
                          jenisHak == null)) ||
                  (jenisDokumen == 'Warkah' &&
                      (jenisWarkah == null ||
                          tahunWarkahController.text.trim().isEmpty))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lengkapi data arsip terlebih dahulu.'),
                  ),
                );
                return;
              }

              setSheetState(() => saving = true);
              final payload = <String, dynamic>{
                'jenis_dokumen': jenisDokumen,
                'jenis_hak': jenisDokumen == 'Warkah' ? null : jenisHak,
                'no_hak': jenisDokumen == 'Warkah'
                    ? null
                    : noHakController.text.trim(),
                'kecamatan': kecamatan,
                'kelurahan': jenisDokumen == 'Buku Tanah' ? kelurahan : null,
                'jenis_surat_ukur': jenisSuratUkur,
                'no_tahun_surat_ukur': noTahunController.text.trim().isEmpty
                    ? null
                    : noTahunController.text.trim(),
                'su': suController.text.trim().isEmpty
                    ? null
                    : suController.text.trim(),
                'gs': gsController.text.trim().isEmpty
                    ? null
                    : gsController.text.trim(),
                'jenis_warkah': jenisWarkah,
                'no_208': no208Controller.text.trim().isEmpty
                    ? null
                    : no208Controller.text.trim(),
                'tahun_warkah': tahunWarkahController.text.trim().isEmpty
                    ? null
                    : tahunWarkahController.text.trim(),
              };

              try {
                await Supabase.instance.client
                    .from('master_arsip')
                    .insert(payload);
                if (sheetContext.mounted) Navigator.pop(sheetContext, true);
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menambahkan arsip: $e'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            }

            // Styled to match form_page.dart's _label/_textField/
            // _dropdownField (muted surface, icon prefix, label above
            // the field) — this sheet used to fall back to plain
            // Material TextField/DropdownButtonFormField with floating
            // labelText, which looked visually out of place next to the
            // rest of the app's forms.
            Widget renderLabel(String text, {bool isDisabled = false}) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDisabled ? Colors.black38 : AppTheme.textSecondary,
                  ),
                ),
              );
            }

            Widget field(
              String label,
              TextEditingController controller, {
              required IconData icon,
              String? placeholder,
              TextInputType keyboardType = TextInputType.text,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    renderLabel(label),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: placeholder,
                          hintStyle: const TextStyle(
                            color: Colors.black38,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            icon,
                            size: 18,
                            color: Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget dropdown<T>({
              required String label,
              required IconData icon,
              required T? value,
              required List<T> items,
              required ValueChanged<T?> onChanged,
              String? placeholder,
              bool isDisabled = false,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    renderLabel(label, isDisabled: isDisabled),
                    Container(
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? const Color(0xFFEEEEEE)
                            : AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<T>(
                          value: items.contains(value) ? value : null,
                          isExpanded: true,
                          hint: Row(
                            children: [
                              const SizedBox(width: 8),
                              Icon(
                                icon,
                                size: 18,
                                color: isDisabled
                                    ? Colors.black26
                                    : Colors.black38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  placeholder ?? 'Pilih $label',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDisabled
                                        ? Colors.black26
                                        : Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          selectedItemBuilder: (ctx) => items
                              .map(
                                (item) => Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Icon(
                                      icon,
                                      size: 18,
                                      color: AppTheme.accentGreen,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                          items: isDisabled
                              ? null
                              : items
                                    .map(
                                      (item) => DropdownMenuItem<T>(
                                        value: item,
                                        child: Text(
                                          item.toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          onChanged: isDisabled ? null : onChanged,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDisabled ? Colors.black26 : Colors.black45,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Jenis Dokumen selector — icon+label chip row, identical in
            // spirit to form_page.dart's _buildJenisDokumenChips(). This
            // used to be a bare DropdownButtonFormField, which buried the
            // single most important choice in the sheet (it decides every
            // field shown below it) behind the same visual weight as
            // "Kelurahan" or "SU (opsional)".
            const jenisDokumenIcons = {
              'Buku Tanah': Icons.menu_book_outlined,
              'Surat Ukur': Icons.straighten_outlined,
              'Warkah': Icons.folder_copy_outlined,
            };
            const jenisDokumenOptions = ['Buku Tanah', 'Surat Ukur', 'Warkah'];

            Widget jenisDokumenChips() {
              return Row(
                children: jenisDokumenOptions.map((jenis) {
                  final isSelected = jenisDokumen == jenis;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: jenis == jenisDokumenOptions.last ? 0 : 10,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setSheetState(() {
                          jenisDokumen = jenis;
                          jenisHak = null;
                          jenisSuratUkur = null;
                          jenisWarkah = null;
                          kecamatan = null;
                          kelurahan = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentGreen.withValues(alpha: 0.10)
                                : AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentGreen
                                  : Colors.transparent,
                              width: 1.4,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                jenisDokumenIcons[jenis],
                                size: 22,
                                color: isSelected
                                    ? AppTheme.accentGreen
                                    : Colors.black45,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                jenis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppTheme.accentGreen
                                      : Colors.black54,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }

            // BUG FIX (transparent sheet): showModalBottomSheet above sets
            // backgroundColor: Colors.transparent so the sheet's own
            // rounded-corner shape doesn't clash with this content's —
            // but that means the sheet has NO opaque surface unless this
            // builder supplies one itself. This used to return the form
            // directly with no Container around it at all, so it rendered
            // fully see-through, with the Archive list showing right
            // through every field underneath. _showArchiveDetail already
            // does this correctly (white Container, rounded top) — same
            // fix here.
            //
            // BUG FIX (sheet jumping on Jenis Dokumen tap): this used to
            // have no height constraint at all, so the sheet shrink-wrapped
            // to whatever fields the current jenisDokumen needed — every
            // tap on a chip changed that field count, which resized the
            // whole sheet and, since a bottom sheet's bottom edge is
            // pinned to the screen bottom, made the top edge visibly jump
            // up or down. Pinning the sheet to a fixed height means a chip
            // tap only changes what's inside the scroll view — new fields
            // appear below the fold instead of the container itself moving.
            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.sheetBody,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // ── Header — same solid gradient + icon-chip + close
                    // button pattern as HistoryPage's "Edit Peminjaman"
                    // sheet, instead of a bare drag handle + plain title.
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: AppTheme.brandGradient,
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.note_add_rounded,
                                    size: 20,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tambah Arsip',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Daftarkan dokumen fisik baru',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    Navigator.pop(sheetContext);
                                  },
                                  child: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              renderLabel('Jenis Dokumen'),
                              jenisDokumenChips(),
                              const SizedBox(height: 16),
                              if (jenisDokumen == 'Buku Tanah') ...[
                                dropdown<String>(
                                  label: 'Jenis Hak',
                                  icon: Icons.shield_outlined,
                                  placeholder: 'Pilih Hak',
                                  value: jenisHak,
                                  items: Data.jenisHak,
                                  onChanged: (v) =>
                                      setSheetState(() => jenisHak = v),
                                ),
                                field(
                                  'Nomor Hak',
                                  noHakController,
                                  icon: Icons.tag,
                                  placeholder: 'cth: 12345',
                                  keyboardType: TextInputType.number,
                                ),
                                dropdown<String>(
                                  label: 'Kecamatan',
                                  icon: Icons.location_city_outlined,
                                  placeholder: 'Pilih Kecamatan',
                                  value: kecamatan,
                                  items: Data.kecamatan,
                                  onChanged: (v) => setSheetState(() {
                                    kecamatan = v;
                                    kelurahan = null;
                                  }),
                                ),
                                dropdown<String>(
                                  label: 'Kelurahan',
                                  icon: Icons.map_outlined,
                                  placeholder: kecamatan == null
                                      ? 'Pilih Kecamatan dahulu'
                                      : 'Pilih Kelurahan',
                                  isDisabled: kecamatan == null,
                                  value: kelurahan,
                                  items: kelurahanOptions,
                                  onChanged: (v) =>
                                      setSheetState(() => kelurahan = v),
                                ),
                              ] else if (jenisDokumen == 'Surat Ukur') ...[
                                dropdown<String>(
                                  label: 'Jenis Surat Ukur',
                                  icon: Icons.straighten_outlined,
                                  placeholder: 'Pilih SU atau GS',
                                  value: jenisSuratUkur,
                                  items: const ['SU', 'GS'],
                                  onChanged: (v) =>
                                      setSheetState(() => jenisSuratUkur = v),
                                ),
                                field(
                                  'Nomor Hak',
                                  noHakController,
                                  icon: Icons.tag,
                                  placeholder: 'cth: 12345',
                                  keyboardType: TextInputType.number,
                                ),
                                field(
                                  'No. & Tahun',
                                  noTahunController,
                                  icon: Icons.numbers_outlined,
                                  placeholder: 'cth: 64/2023',
                                ),
                                dropdown<String>(
                                  label: 'Jenis Hak',
                                  icon: Icons.shield_outlined,
                                  placeholder: 'Pilih Hak',
                                  value: jenisHak,
                                  items: Data.jenisHak,
                                  onChanged: (v) =>
                                      setSheetState(() => jenisHak = v),
                                ),
                                field(
                                  'SU (opsional)',
                                  suController,
                                  icon: Icons.numbers_outlined,
                                ),
                                field(
                                  'GS (opsional)',
                                  gsController,
                                  icon: Icons.numbers_outlined,
                                ),
                              ] else ...[
                                dropdown<String>(
                                  label: 'Jenis Warkah',
                                  icon: Icons.folder_copy_outlined,
                                  placeholder: 'Pilih Jenis Warkah',
                                  value: jenisWarkah,
                                  items: const ['BN', 'Subsi III', 'PBT'],
                                  onChanged: (v) =>
                                      setSheetState(() => jenisWarkah = v),
                                ),
                                if (jenisWarkah == 'PBT')
                                  dropdown<String>(
                                    label: 'Kecamatan',
                                    icon: Icons.location_city_outlined,
                                    placeholder: 'Pilih Kecamatan',
                                    value: kecamatan,
                                    items: Data.kecamatan,
                                    onChanged: (v) =>
                                        setSheetState(() => kecamatan = v),
                                  ),
                                field(
                                  'No. 208',
                                  no208Controller,
                                  icon: Icons.tag,
                                  placeholder: 'cth: 12345',
                                  keyboardType: TextInputType.number,
                                ),
                                field(
                                  'Tahun Warkah',
                                  tahunWarkahController,
                                  icon: Icons.calendar_today_outlined,
                                  placeholder: 'cth: 2020',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: saving ? null : save,
                                  icon: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    saving ? 'Menyimpan...' : 'Simpan Arsip',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // BUG FIX (crash: "A TextEditingController was used after being
    // disposed"): the Future from showModalBottomSheet resolves the
    // instant Navigator.pop() runs, but the sheet's closing animation
    // keeps rendering for ~250ms after that — the TextFields inside it
    // are still being laid out during that reverse transition. Disposing
    // their controllers immediately here raced with that animation and
    // crashed. Delaying disposal past the transition avoids the race.
    if (saved == true && mounted) await _fetchMasterArsip();
    Future.delayed(const Duration(milliseconds: 300), () {
      noHakController.dispose();
      noTahunController.dispose();
      suController.dispose();
      gsController.dispose();
      no208Controller.dispose();
      tahunWarkahController.dispose();
    });
  }

  // Display detailed information about an archive document in a bottom sheet,
  // with edit/delete options for admins.
  //
  // FEATURE (item 7): this used to hardcode the status pill to "Tersedia"
  // no matter what — so an admin deciding whether to approve a new
  // borrow request had no way to tell, from this page, whether the
  // physical document was already out (or already requested) elsewhere.
  // Now it looks the document up against PeminjamanService's cache via
  // findActiveLoanForArsip and reflects the real state.
  Future<void> _showArchiveDetail(Map<String, dynamic> arsip) async {
    final jenis = arsip['jenis_dokumen'] ?? 'Buku Tanah';
    final accent = _jenisColors[jenis] ?? AppTheme.primaryGreen;
    final activeLoan = PeminjamanService.findActiveLoanForArsip(arsip);
    final isAvailable = activeLoan == null;
    final isPending = activeLoan?.status == 'Diajukan';
    final isOverdue = activeLoan?.status == 'Dipinjam' && activeLoan!.isOverdue;

    // Same status-color language History/Return already use (see
    // history_page.dart's _statusColor/_statusBg) — Tersedia mirrors
    // 'Kembali' (accentGreen/successBg), Sedang Dipinjam mirrors
    // 'Dipinjam' (warningAmber/warningBg, or dangerRed/dangerBg once
    // overdue), Sedang Diajukan mirrors 'Diajukan' (the same darker
    // amber History uses, still on a warningBg chip). Was briefly
    // dangerRed for any non-available state — wrong per the theme file's
    // own comments, which reserve dangerRed for "Terlambat"/rejected,
    // not "currently on loan."
    const diajukanAmber = Color(0xFF8A6D00);
    final Color statusColor = isAvailable
        ? AppTheme.accentGreen
        : isOverdue
        ? AppTheme.dangerRed
        : isPending
        ? diajukanAmber
        : AppTheme.warningAmber;
    final Color statusBg = isAvailable
        ? AppTheme.successBg
        : isOverdue
        ? AppTheme.dangerBg
        : AppTheme.warningBg;
    final String statusLabel = isAvailable
        ? 'Tersedia'
        : isOverdue
        ? 'Terlambat Dikembalikan'
        : isPending
        ? 'Sedang Diajukan'
        : 'Sedang Dipinjam';

    Widget infoRow(IconData icon, String label, String? value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: accent),
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
                    value ?? '-',
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
        // Capped at half the screen height (was unbounded — a document
        // with every optional field filled in, plus the admin
        // Edit/Hapus row, could push the sheet all the way to the top
        // of the screen). SingleChildScrollView below already handles
        // overflow, so this just gives it a ceiling to scroll within.
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Container(
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
                        backgroundColor: accent.withValues(alpha: 0.12),
                        child: Icon(
                          jenis == 'Buku Tanah'
                              ? Icons.menu_book_outlined
                              : jenis == 'Surat Ukur'
                              ? Icons.straighten_outlined
                              : Icons.folder_copy_outlined,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jenis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'ID: ${arsip['id'] ?? 'N/A'}',
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
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 18),

                  // Peminjaman info — only shown when the document isn't
                  // free, so an admin reviewing a new request can see at a
                  // glance who has it (or who else asked first) without
                  // leaving this sheet to go dig through History.
                  //
                  // Checked as `activeLoan != null` rather than
                  // `!isAvailable` here on purpose — the analyzer promotes
                  // activeLoan to non-null from a direct null check on
                  // itself, but not from a separate derived bool that
                  // merely happens to be equivalent.
                  if (activeLoan != null) ...[
                    infoRow(
                      Icons.person_outline,
                      isPending ? 'Diajukan Oleh' : 'Dipinjam Oleh',
                      activeLoan.nama,
                    ),
                    infoRow(
                      isPending
                          ? Icons.pending_actions_outlined
                          : Icons.event_outlined,
                      isPending ? 'Tanggal Pengajuan' : 'Sejak Tanggal',
                      activeLoan.tanggalPinjamFormatted,
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Common fields
                  infoRow(Icons.category_outlined, 'Jenis Dokumen', jenis),

                  // Buku Tanah fields
                  if (jenis == 'Buku Tanah') ...[
                    infoRow(
                      Icons.description_outlined,
                      'Jenis Hak',
                      arsip['jenis_hak'],
                    ),
                    infoRow(
                      Icons.numbers_outlined,
                      'Nomor Hak',
                      arsip['no_hak'],
                    ),
                    infoRow(
                      Icons.location_on_outlined,
                      'Kecamatan',
                      arsip['kecamatan'],
                    ),
                    infoRow(
                      Icons.location_city_outlined,
                      'Kelurahan',
                      arsip['kelurahan'],
                    ),
                  ] else if (jenis == 'Surat Ukur') ...[
                    infoRow(
                      Icons.description_outlined,
                      'Jenis Surat Ukur',
                      arsip['jenis_surat_ukur'],
                    ),
                    infoRow(
                      Icons.numbers_outlined,
                      'No. & Tahun',
                      arsip['no_tahun_surat_ukur'],
                    ),
                    infoRow(
                      Icons.description_outlined,
                      'Jenis Hak',
                      arsip['jenis_hak'],
                    ),
                    infoRow(Icons.description_outlined, 'SU', arsip['su']),
                    infoRow(Icons.description_outlined, 'GS', arsip['gs']),
                  ] else if (jenis == 'Warkah') ...[
                    infoRow(
                      Icons.description_outlined,
                      'Jenis Warkah',
                      arsip['jenis_warkah'],
                    ),
                    infoRow(Icons.numbers_outlined, 'No. 208', arsip['no_208']),
                    infoRow(
                      Icons.calendar_today_outlined,
                      'Tahun Warkah',
                      arsip['tahun_warkah'],
                    ),
                    if (arsip['jenis_warkah'] == 'PBT')
                      infoRow(
                        Icons.location_on_outlined,
                        'Kecamatan',
                        arsip['kecamatan'],
                      ),
                  ],

                  const SizedBox(height: 8),

                  // Admin buttons — was two full-width filled ElevatedButtons
                  // stacked vertically (Edit Arsip, then Hapus Arsip below
                  // it); every other admin edit/delete pair in the app
                  // (History's Edit/Hapus, shown above) is a side-by-side
                  // OutlinedButton Row instead, so this was the one detail
                  // sheet that looked like a different app. Same
                  // OutlinedButton.icon style, same red.shade400/red.shade200
                  // for delete (kept literal to match History's exact
                  // values rather than swapping in AppTheme.dangerRed,
                  // which reads slightly darker).
                  if (AuthService.isAdmin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditArchiveSheet(arsip);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: const BorderSide(
                                color: AppTheme.primaryGreen,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Hapus Arsip'),
                                  content: const Text(
                                    'Apakah Anda yakin ingin menghapus arsip ini? Tindakan ini tidak dapat dibatalkan.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                try {
                                  await Supabase.instance.client
                                      .from('master_arsip')
                                      .delete()
                                      .eq('id', arsip['id']);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Arsip berhasil dihapus.',
                                        ),
                                        backgroundColor: AppTheme.accentGreen,
                                      ),
                                    );
                                    await _fetchMasterArsip();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Gagal menghapus arsip: $e',
                                        ),
                                        backgroundColor: AppTheme.dangerRed,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red.shade400,
                            ),
                            label: Text(
                              'Hapus',
                              style: TextStyle(color: Colors.red.shade400),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade200),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Edit an existing archive document.
  Future<void> _showEditArchiveSheet(Map<String, dynamic> arsip) async {
    if (!AuthService.isAdmin) return;

    final noHakController = TextEditingController(text: arsip['no_hak'] ?? '');
    final noTahunController = TextEditingController(
      text: arsip['no_tahun_surat_ukur'] ?? '',
    );
    final suController = TextEditingController(text: arsip['su'] ?? '');
    final gsController = TextEditingController(text: arsip['gs'] ?? '');
    final no208Controller = TextEditingController(text: arsip['no_208'] ?? '');
    final tahunWarkahController = TextEditingController(
      text: arsip['tahun_warkah'] ?? '',
    );

    String jenisDokumen = arsip['jenis_dokumen'] ?? 'Buku Tanah';
    String? jenisHak = arsip['jenis_hak'];
    String? jenisSuratUkur = arsip['jenis_surat_ukur'];
    String? jenisWarkah = arsip['jenis_warkah'];
    String? kecamatan = arsip['kecamatan'];
    String? kelurahan = arsip['kelurahan'];
    bool saving = false;

    // Header subtitle ("Buku Tanah · 5646/Panggung Rawi") — matches the
    // jenis + identifier line HistoryPage shows in its Edit Peminjaman
    // header. Based on the document as it was when the sheet was opened,
    // same as that reference (doesn't live-update as fields change).
    final headerJenis = arsip['jenis_dokumen'] ?? 'Buku Tanah';
    final headerIdentifier = headerJenis == 'Warkah'
        ? 'No. 208: ${arsip['no_208'] ?? '-'}'
        : '${arsip['no_hak'] ?? '-'}/${arsip['kelurahan'] ?? '-'}';

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final kelurahanOptions = kecamatan == null
                ? const <String>[]
                : (Data.kelurahan[kecamatan] ?? const <String>[]);

            Future<void> save() async {
              setSheetState(() => saving = true);
              final payload = <String, dynamic>{
                'jenis_dokumen': jenisDokumen,
                'jenis_hak': jenisDokumen == 'Warkah' ? null : jenisHak,
                'no_hak': jenisDokumen == 'Warkah'
                    ? null
                    : noHakController.text.trim(),
                'kecamatan': kecamatan,
                'kelurahan': jenisDokumen == 'Buku Tanah' ? kelurahan : null,
                'jenis_surat_ukur': jenisSuratUkur,
                'no_tahun_surat_ukur': noTahunController.text.trim().isEmpty
                    ? null
                    : noTahunController.text.trim(),
                'su': suController.text.trim().isEmpty
                    ? null
                    : suController.text.trim(),
                'gs': gsController.text.trim().isEmpty
                    ? null
                    : gsController.text.trim(),
                'jenis_warkah': jenisWarkah,
                'no_208': no208Controller.text.trim().isEmpty
                    ? null
                    : no208Controller.text.trim(),
                'tahun_warkah': tahunWarkahController.text.trim().isEmpty
                    ? null
                    : tahunWarkahController.text.trim(),
              };

              try {
                await Supabase.instance.client
                    .from('master_arsip')
                    .update(payload)
                    .eq('id', arsip['id']);
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Arsip berhasil diperbarui.'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                  _fetchMasterArsip();
                }
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal memperbarui arsip: $e'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            }

            // Styled to match form_page.dart's _label/_textField/
            // _dropdownField (muted surface, icon prefix, label above
            // the field) — this sheet used to fall back to plain
            // Material TextField/DropdownButtonFormField with floating
            // labelText, which looked visually out of place next to the
            // rest of the app's forms.
            Widget renderLabel(String text, {bool isDisabled = false}) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDisabled ? Colors.black38 : AppTheme.textSecondary,
                  ),
                ),
              );
            }

            Widget field(
              String label,
              TextEditingController controller, {
              required IconData icon,
              String? placeholder,
              TextInputType keyboardType = TextInputType.text,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    renderLabel(label),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: placeholder,
                          hintStyle: const TextStyle(
                            color: Colors.black38,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            icon,
                            size: 18,
                            color: Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget dropdown<T>({
              required String label,
              required IconData icon,
              required T? value,
              required List<T> items,
              required ValueChanged<T?> onChanged,
              String? placeholder,
              bool isDisabled = false,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    renderLabel(label, isDisabled: isDisabled),
                    Container(
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? const Color(0xFFEEEEEE)
                            : AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<T>(
                          value: items.contains(value) ? value : null,
                          isExpanded: true,
                          hint: Row(
                            children: [
                              const SizedBox(width: 8),
                              Icon(
                                icon,
                                size: 18,
                                color: isDisabled
                                    ? Colors.black26
                                    : Colors.black38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  placeholder ?? 'Pilih $label',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDisabled
                                        ? Colors.black26
                                        : Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          selectedItemBuilder: (ctx) => items
                              .map(
                                (item) => Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Icon(
                                      icon,
                                      size: 18,
                                      color: AppTheme.accentGreen,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                          items: isDisabled
                              ? null
                              : items
                                    .map(
                                      (item) => DropdownMenuItem<T>(
                                        value: item,
                                        child: Text(
                                          item.toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          onChanged: isDisabled ? null : onChanged,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDisabled ? Colors.black26 : Colors.black45,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Jenis Dokumen selector — icon+label chip row, identical in
            // spirit to form_page.dart's _buildJenisDokumenChips(). This
            // used to be a bare DropdownButtonFormField, which buried the
            // single most important choice in the sheet (it decides every
            // field shown below it) behind the same visual weight as
            // "Kelurahan" or "SU (opsional)".
            const jenisDokumenIcons = {
              'Buku Tanah': Icons.menu_book_outlined,
              'Surat Ukur': Icons.straighten_outlined,
              'Warkah': Icons.folder_copy_outlined,
            };
            const jenisDokumenOptions = ['Buku Tanah', 'Surat Ukur', 'Warkah'];

            Widget jenisDokumenChips() {
              return Row(
                children: jenisDokumenOptions.map((jenis) {
                  final isSelected = jenisDokumen == jenis;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: jenis == jenisDokumenOptions.last ? 0 : 10,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setSheetState(() {
                          jenisDokumen = jenis;
                          jenisHak = null;
                          jenisSuratUkur = null;
                          jenisWarkah = null;
                          kecamatan = null;
                          kelurahan = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentGreen.withValues(alpha: 0.10)
                                : AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentGreen
                                  : Colors.transparent,
                              width: 1.4,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                jenisDokumenIcons[jenis],
                                size: 22,
                                color: isSelected
                                    ? AppTheme.accentGreen
                                    : Colors.black45,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                jenis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppTheme.accentGreen
                                      : Colors.black54,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }

            // BUG FIX (transparent sheet): same fix as _showAddArchiveSheet
            // above — showModalBottomSheet's backgroundColor: Colors.
            // transparent means this builder is on the hook for its own
            // opaque surface, and this one never had one either.
            //
            // BUG FIX (sheet jumping on Jenis Dokumen tap): same fix as
            // _showAddArchiveSheet — pin to a fixed height so switching
            // jenisDokumen only changes what's inside the scroll view
            // instead of resizing (and visibly shifting) the whole sheet.
            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.sheetBody,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // ── Header — same solid gradient + icon-chip + close
                    // button pattern as HistoryPage's "Edit Peminjaman"
                    // sheet, instead of a bare drag handle + plain title.
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: AppTheme.brandGradient,
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.edit_document,
                                    size: 20,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Edit Arsip',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$headerJenis · $headerIdentifier',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    Navigator.pop(sheetContext);
                                  },
                                  child: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              renderLabel('Jenis Dokumen'),
                              jenisDokumenChips(),
                              const SizedBox(height: 16),
                              if (jenisDokumen == 'Buku Tanah') ...[
                                dropdown<String>(
                                  label: 'Jenis Hak',
                                  icon: Icons.shield_outlined,
                                  placeholder: 'Pilih Hak',
                                  value: jenisHak,
                                  items: Data.jenisHak,
                                  onChanged: (v) =>
                                      setSheetState(() => jenisHak = v),
                                ),
                                field(
                                  'Nomor Hak',
                                  noHakController,
                                  icon: Icons.tag,
                                  placeholder: 'cth: 12345',
                                  keyboardType: TextInputType.number,
                                ),
                                dropdown<String>(
                                  label: 'Kecamatan',
                                  icon: Icons.location_city_outlined,
                                  placeholder: 'Pilih Kecamatan',
                                  value: kecamatan,
                                  items: Data.kecamatan,
                                  onChanged: (v) => setSheetState(() {
                                    kecamatan = v;
                                    kelurahan = null;
                                  }),
                                ),
                                dropdown<String>(
                                  label: 'Kelurahan',
                                  icon: Icons.map_outlined,
                                  placeholder: kecamatan == null
                                      ? 'Pilih Kecamatan dahulu'
                                      : 'Pilih Kelurahan',
                                  isDisabled: kecamatan == null,
                                  value: kelurahan,
                                  items: kelurahanOptions,
                                  onChanged: (v) =>
                                      setSheetState(() => kelurahan = v),
                                ),
                              ] else if (jenisDokumen == 'Surat Ukur') ...[
                                dropdown<String>(
                                  label: 'Jenis Surat Ukur',
                                  icon: Icons.straighten_outlined,
                                  placeholder: 'Pilih SU atau GS',
                                  value: jenisSuratUkur,
                                  items: const ['SU', 'GS'],
                                  onChanged: (v) =>
                                      setSheetState(() => jenisSuratUkur = v),
                                ),
                                field(
                                  'Nomor Hak',
                                  noHakController,
                                  icon: Icons.tag,
                                  placeholder: 'cth: 12345',
                                  keyboardType: TextInputType.number,
                                ),
                                field(
                                  'No. & Tahun',
                                  noTahunController,
                                  icon: Icons.numbers_outlined,
                                  placeholder: 'cth: 64/2023',
                                ),
                                dropdown<String>(
                                  label: 'Jenis Hak',
                                  icon: Icons.shield_outlined,
                                  placeholder: 'Pilih Hak',
                                  value: jenisHak,
                                  items: Data.jenisHak,
                                  onChanged: (v) =>
                                      setSheetState(() => jenisHak = v),
                                ),
                                field(
                                  'SU (opsional)',
                                  suController,
                                  icon: Icons.numbers_outlined,
                                ),
                                field(
                                  'GS (opsional)',
                                  gsController,
                                  icon: Icons.numbers_outlined,
                                ),
                              ] else ...[
                                dropdown<String>(
                                  label: 'Jenis Warkah',
                                  icon: Icons.folder_copy_outlined,
                                  placeholder: 'Pilih Jenis Warkah',
                                  value: jenisWarkah,
                                  items: const ['BN', 'Subsi III', 'PBT'],
                                  onChanged: (v) =>
                                      setSheetState(() => jenisWarkah = v),
                                ),
                                if (jenisWarkah == 'PBT')
                                  dropdown<String>(
                                    label: 'Kecamatan',
                                    icon: Icons.location_city_outlined,
                                    placeholder: 'Pilih Kecamatan',
                                    value: kecamatan,
                                    items: Data.kecamatan,
                                    onChanged: (v) =>
                                        setSheetState(() => kecamatan = v),
                                  ),
                                field(
                                  'No. 208',
                                  no208Controller,
                                  icon: Icons.tag,
                                  placeholder: 'cth: 12345',
                                  keyboardType: TextInputType.number,
                                ),
                                field(
                                  'Tahun Warkah',
                                  tahunWarkahController,
                                  icon: Icons.calendar_today_outlined,
                                  placeholder: 'cth: 2020',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: saving ? null : save,
                                  icon: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    saving
                                        ? 'Menyimpan...'
                                        : 'Simpan Perubahan',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Same fix as _showAddArchiveSheet above.
    Future.delayed(const Duration(milliseconds: 300), () {
      noHakController.dispose();
      noTahunController.dispose();
      suController.dispose();
      gsController.dispose();
      no208Controller.dispose();
      tahunWarkahController.dispose();
    });
  }

  Widget _buildItem(Map<String, dynamic> arsip) {
    final jenis = arsip['jenis_dokumen'] ?? 'Buku Tanah';
    String title = '';
    String subtitle = '';
    IconData icon = Icons.description;
    final accent = _jenisColors[jenis] ?? AppTheme.primaryGreen;
    // Same lookup _showArchiveDetail uses — surfaced here too so an admin
    // scanning the list can spot an unavailable document without opening
    // every card one by one.
    final isAvailable = PeminjamanService.findActiveLoanForArsip(arsip) == null;

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
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showArchiveDetail(arsip),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: accent, width: 4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(icon, color: accent),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAvailable
                              ? AppTheme.accentGreen
                              : AppTheme.warningAmber,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAvailable ? 'Tersedia' : 'Dipinjam',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? AppTheme.accentGreen
                              : AppTheme.warningAmber,
                        ),
                      ),
                    ],
                  ),
                ],
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(height: 6),
            Text(
              '$count',
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

  // ─── STATUS CHIPS (Document Type Filter) ───
  // Semua/Buku Tanah/Surat Ukur/Warkah — same styling pattern as History's
  // status chips (Semua/Sedang Dipinjam/Telah Kembali), instead of plain
  // rounded containers. Expanded child ensures each chip scales to fill
  // available width evenly, and centerText looks consistent.
  Widget _buildJenisChips() {
    Widget chip(String label, String? value) {
      final selected = _selectedJenis == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedJenis = value);
            _filterSearch();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? _accentGreen : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
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

    return Row(
      children: [
        chip('Semua', null),
        const SizedBox(width: 8),
        chip('Buku Tanah', 'Buku Tanah'),
        const SizedBox(width: 8),
        chip('Surat Ukur', 'Surat Ukur'),
        const SizedBox(width: 8),
        chip('Warkah', 'Warkah'),
      ],
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
      // Outer Stack just to float _buildAddArchiveButton above the list
      // (bottom-right, admin-only) without disturbing AppScanFab, which
      // already owns the centerDocked slot via floatingActionButton
      // above — the two need to coexist without colliding, and Scaffold
      // only has one floatingActionButton slot, so the second button is
      // laid out here instead, as a plain Positioned overlay.
      body: Stack(
        children: [
          _buildArchiveBody(),
          if (AuthService.isAdmin) _buildAddArchiveButton(context),
        ],
      ),
    );
  }

  Widget _buildArchiveBody() {
    return Column(
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
                  decoration: const BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      child: Column(
                        children: [
                          // "Tambah arsip" used to live here as a lone
                          // IconButton bolted onto AppTopBar's row — the
                          // only page in the whole app where AppTopBar
                          // wasn't the full width of its row, and the
                          // only add/create action anywhere that lived in
                          // a top bar instead of its own control. It's
                          // now a floating pill button (see
                          // _buildAddArchiveButton) docked bottom-right,
                          // same idea as the reference screenshot but
                          // labeled so its purpose doesn't rely on the
                          // user already knowing what a bare "+" does.
                          const AppTopBar(title: 'Inventaris Arsip'),
                          const SizedBox(height: 14),
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
                              const SizedBox(width: 10),
                              _statBox(
                                icon: Icons.menu_book_outlined,
                                count: _countJenis('Buku Tanah'),
                                label: 'Buku\nTanah',
                              ),
                              const SizedBox(width: 10),
                              _statBox(
                                icon: Icons.straighten_outlined,
                                count: _countJenis('Surat Ukur'),
                                label: 'Surat\nUkur',
                              ),
                              const SizedBox(width: 10),
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
                ),
                const SizedBox(height: 40),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Cari nomor hak, warkah, kelurahan...',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 13.5),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.black38,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Fixed spacing between search card and filter chips—
        // increased from 14 to account for the search card hanging down
        // from the header. The overlap is deliberate (card straddles the
        // boundary), so the first chip row sits lower to avoid collision.
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildJenisChips(),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading && _arsipList.isEmpty
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
    );
  }

  Widget _buildAddArchiveButton(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Positioned(
      right: 20,
      bottom: 20,
      child: keyboardOpen
          ? const SizedBox.shrink()
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAddArchiveSheet,
                borderRadius: BorderRadius.circular(30),
                child: Ink(
                  padding: const EdgeInsets.fromLTRB(18, 14, 20, 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Tambah Arsip',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
