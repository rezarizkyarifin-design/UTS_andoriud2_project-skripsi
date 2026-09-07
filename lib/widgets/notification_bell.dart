import 'dart:async';

import 'package:flutter/material.dart';
import '../screens/services/auth_service.dart';
import '../screens/services/peminjaman_service.dart';
import '../models/peminjaman.dart';
import '../routes/app_routes.dart';
import '../core/theme/app_theme.dart';

enum _NotifType { newLoanRequest, extensionRequest, overdue }

class _AppNotification {
  final _NotifType type;
  final Peminjaman peminjaman;
  const _AppNotification({required this.type, required this.peminjaman});
}

/// Self-contained bell icon + badge + dropdown notification panel.
///
/// Drop this into any page's header in place of the old duplicated
/// IconButton/_showNotifications()/_notifCount() trio that used to live
/// separately in home_page.dart, history_page.dart, and return_page.dart
/// — this widget reads directly from PeminjamanService/AuthService, so
/// no data needs to be passed in and there's only one place left to fix
/// if the notification rules ever change.
///
/// Notifications are exactly three kinds, combined into one list:
///  - pending pengajuan peminjaman (new loan requests) — Admin only,
///    since only Admin can approve/reject them
///    (PeminjamanService.setujuiPeminjaman/tolakPeminjaman)
///  - pending perpanjangan (extension) requests — Admin only, since only
///    Admin can approve/reject them (PeminjamanService.setujuiPerpanjangan)
///  - overdue (terlambat) active loans — see
///    PeminjamanService.getOverdueForNotifikasi() for the Admin/Pegawai
///    scoping rule.
///
/// Tapping a notification closes the panel and navigates somewhere the
/// admin can act on it: a new loan request goes to HomePage (where the
/// approval banner + bottom sheet live), extension requests and overdue
/// loans go to ReturnPage (where approving extensions and marking
/// documents returned already live) — see _handleTap.
class NotificationBell extends StatefulWidget {
  final Color iconColor;
  const NotificationBell({super.key, this.iconColor = Colors.white});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _open = false;

  // ─── Layer 1 (14.08.2026): auto-refresh ──────────────────────────
  // PeminjamanService's cache is only ever repopulated on explicit
  // refresh() calls (app start, pull-to-refresh, after certain actions)
  // — there's no realtime subscription, so an Admin sitting on a page
  // never found out about a new pengajuan from another device until
  // they happened to navigate somewhere that re-triggers refresh(), or
  // restarted the app. This bell is on every main page's header, so a
  // single Timer here — rather than duplicating one per page — keeps
  // the badge/dropdown reasonably live everywhere at once.
  //
  // This calls the SAME refresh() every other pull-to-refresh/page-load
  // already uses (full cache replace), not a lighter "just check the
  // count" query — kept deliberately simple so the badge count and the
  // dropdown's actual list contents can never disagree with each other.
  // Tradeoff: a background poll can reorder/refresh whatever list a
  // Pegawai is actively scrolling on History/Return mid-poll. 25s is
  // slow enough that this is rare, and refresh() is additive-looking
  // (newest-first) rather than jarring, so this is an acceptable
  // tradeoff for the simplicity — revisit with a narrower "just the
  // pending/overdue counts" query if that ever becomes a real complaint.
  static const _pollInterval = Duration(seconds: 25);
  Timer? _pollTimer;
  int _lastKnownCount = 0;

  @override
  void initState() {
    super.initState();
    _lastKnownCount = _buildNotifications().length;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      await PeminjamanService.refresh();
    } catch (_) {
      // Offline or a transient error — just skip this tick silently.
      // The existing error-banner pattern on History/Return already
      // surfaces connectivity problems when the person is actually
      // looking at a list; this background poll doesn't need to nag
      // about it too.
      return;
    }
    if (!mounted) return;
    final newCount = _buildNotifications().length;
    if (newCount != _lastKnownCount) {
      setState(() => _lastKnownCount = newCount);
    }
  }

  List<_AppNotification> _buildNotifications() {
    final list = <_AppNotification>[];
    if (AuthService.isAdmin) {
      for (final p in PeminjamanService.getPengajuanPeminjaman()) {
        list.add(
          _AppNotification(type: _NotifType.newLoanRequest, peminjaman: p),
        );
      }
    }
    // Dokumen yang sudah punya notifikasi "pengajuan perpanjangan" tidak
    // perlu juga muncul sebagai notifikasi "terlambat" — dua-duanya
    // merujuk ke dokumen yang sama, jadi tanpa filter ini Admin melihat
    // entri duplikat untuk satu peminjaman. Set ini hanya terisi untuk
    // Admin (pegawai tidak melihat notifikasi pengajuan sama sekali),
    // jadi tampilan overdue untuk pegawai tidak terpengaruh.
    final extensionPendingIds = <String?>{};
    if (AuthService.isAdmin) {
      for (final p in PeminjamanService.getPengajuanPerpanjangan()) {
        list.add(
          _AppNotification(type: _NotifType.extensionRequest, peminjaman: p),
        );
        extensionPendingIds.add(p.id);
      }
    }
    for (final p in PeminjamanService.getOverdueForNotifikasi()) {
      if (extensionPendingIds.contains(p.id)) continue;
      list.add(_AppNotification(type: _NotifType.overdue, peminjaman: p));
    }
    return list;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _open = false;
  }

  void _toggle() {
    if (_open) {
      _removeOverlay();
      setState(() {});
      return;
    }
    final notifications = _buildNotifications();
    _overlayEntry = _buildOverlayEntry(notifications);
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _open = true);
  }

  void _handleTap(_AppNotification n) {
    _removeOverlay();
    if (mounted) setState(() {});
    final destination = n.type == _NotifType.newLoanRequest
        ? AppRoutes.home
        : AppRoutes.returnPage;
    Navigator.pushNamed(context, destination);
  }

  OverlayEntry _buildOverlayEntry(List<_AppNotification> notifications) {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Full-screen transparent tap-catcher so tapping anywhere
            // outside the dropdown dismisses it, same as the reference
            // dashboards' bell dropdowns.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _removeOverlay();
                  if (mounted) setState(() {});
                },
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 10),
              child: _NotificationDropdown(
                notifications: notifications,
                onTapItem: _handleTap,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _buildNotifications().length;
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        tooltip: 'Notifikasi',
        onPressed: _toggle,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_outlined, color: widget.iconColor),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(
                    minWidth: 15,
                    minHeight: 15,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
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

class _NotificationDropdown extends StatefulWidget {
  final List<_AppNotification> notifications;
  final ValueChanged<_AppNotification> onTapItem;

  const _NotificationDropdown({
    required this.notifications,
    required this.onTapItem,
  });

  @override
  State<_NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<_NotificationDropdown> {
  final ScrollController _scrollController = ScrollController();

  // Roughly how tall one tile is, used only to decide when the panel
  // should stop growing and start scrolling instead. Real tiles can be
  // slightly taller/shorter (text wrapping) — that's fine, this is just
  // a cap on the outer container, the ListView inside scrolls normally.
  static const double _approxItemHeight = 90;
  static const int _visibleBeforeScroll = 5;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = widget.notifications;
    // The item-count-based cap below only makes sense once there are
    // actual items to scroll through. The empty state has its own fixed
    // layout (icon + text + padding) that doesn't follow the same
    // per-item math — capping it with that formula is what caused the
    // "BOTTOM OVERFLOWED" error, since the real empty-state content is
    // taller than one estimated item slot. So: no height cap at all
    // when empty, just let it size to its actual (small, fixed) content.
    final maxHeight = notifications.isEmpty
        ? double.infinity
        : (_approxItemHeight *
                  notifications.length.clamp(1, _visibleBeforeScroll)) +
              52;

    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, -8 * (1 - t)),
              child: child,
            ),
          );
        },
        child: Container(
          width: 300,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (notifications.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${notifications.length} baru',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 28,
                        color: Colors.black26,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tidak ada notifikasi baru',
                        style: TextStyle(fontSize: 12.5, color: Colors.black45),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(right: 4),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        return _NotificationTile(
                          notification: n,
                          onTap: () => widget.onTapItem(n),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = notification.peminjaman;
    final isNewLoan = notification.type == _NotifType.newLoanRequest;
    final isExtension = notification.type == _NotifType.extensionRequest;
    final trimmedNama = p.nama.trim();
    final initial = trimmedNama.isNotEmpty ? trimmedNama[0].toUpperCase() : '?';

    final accentColor = isNewLoan
        ? AppTheme.primaryGreen
        : isExtension
        ? const Color(0xFFB07A00)
        : AppTheme.dangerRed;
    final title = isNewLoan
        ? '${p.nama} mengajukan peminjaman'
        : isExtension
        ? '${p.nama} mengajukan perpanjangan'
        : '${p.nama} — dokumen terlambat';
    final statusLine = isNewLoan
        ? 'Menunggu persetujuan • ${p.jenisDokumen}'
        : isExtension
        ? 'Menunggu persetujuan • hingga ${p.requestedTanggalKembaliFormatted ?? '-'}'
        : 'Terlambat ${p.hariTerlambat} hari • batas ${p.tanggalKembaliFormatted}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentColor.withValues(alpha: 0.14),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isNewLoan
                          ? Icons.note_add
                          : isExtension
                          ? Icons.pending_actions
                          : Icons.warning_amber_rounded,
                      size: 12,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.jenisHak} • ${p.noHak}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tgl Pinjam: ${p.tanggalPinjamFormatted}',
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusLine,
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
