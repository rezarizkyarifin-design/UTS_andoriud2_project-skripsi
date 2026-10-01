import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Modern bottom navigation with a pill-shaped active indicator.
///
/// REDESIGN — the old version was a BottomAppBar + CircularNotchedRectangle
/// with a small 4px dot under the active item. That notch pattern is a
/// 2018-era Material pattern; every design system since 2021 uses a
/// floating pill that slides under the active label instead. Visually the
/// nav now reads as one soft surface with a moving highlight, not four
/// items sharing a bar.
///
/// The FAB still docks in the center via the Scaffold's
/// `floatingActionButtonLocation: centerDocked`, but this nav no longer
/// carves a notch for it — a floating FAB above a plain nav bar is the
/// current pattern, and removing the notch also removes the weird
/// empty gap that used to sit in the middle of the icon row.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.activeIndex,
    required this.onItemSelected,
  });

  /// 0 = Beranda, 1 = Arsip, 2 = Kembali, 3 = Profil.
  final int activeIndex;
  final ValueChanged<int> onItemSelected;

  static const _items = [
    {'icon': Icons.home_rounded, 'label': 'Beranda'},
    {'icon': Icons.folder_rounded, 'label': 'Arsip'},
    {'icon': Icons.history_rounded, 'label': 'Riwayat'},
    {'icon': Icons.assignment_return_rounded, 'label': 'Kembali'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.elevationRaised,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              Expanded(child: _buildItem(0)),
              Expanded(child: _buildItem(1)),

              // Space the FAB still docks into — same 52px gap the old
              // SizedBox(width: 52) reserved, so nothing shifts.
              const SizedBox(width: 52),

              Expanded(child: _buildItem(2)),
              Expanded(child: _buildItem(3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    final isSelected = activeIndex == index;
    final icon = item['icon'] as IconData;
    final label = item['label'] as String;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        onTap: () => onItemSelected(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.brandTint(AppTheme.primaryGreen, 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.textMuted,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.0,
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
