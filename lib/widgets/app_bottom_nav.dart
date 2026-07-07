import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

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
    {'icon': Icons.folder_outlined, 'label': 'Arsip'},
    {'icon': Icons.assignment_return, 'label': 'Kembali'},
    {'icon': Icons.person_outline, 'label': 'Profil'},
  ];

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 4,
      height: 68,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            Expanded(child: _buildItem(0)),
            Expanded(child: _buildItem(1)),

            const SizedBox(width: 52),

            Expanded(child: _buildItem(2)),
            Expanded(child: _buildItem(3)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    final isSelected = activeIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item['icon'] as IconData,
            color: isSelected ? AppTheme.primaryGreen : Colors.black38,
            size: 22,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              item['label'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.0,
                color: isSelected ? AppTheme.primaryGreen : Colors.black38,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 4,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1 : 0,
              child: const SizedBox(
                width: 4,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
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
