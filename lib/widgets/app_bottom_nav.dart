import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Shared bottom navigation bar, used identically across every main page.
///
/// This widget is intentionally "dumb" — it only renders and reports taps.
/// Each page decides what a tap on a given index actually *does* (e.g.
/// HomePage does `setState` on index 0 but pushes+refreshes on index 1;
/// HistoryPage does the opposite for its own index). That behavior isn't
/// something a shared widget should own, so it's left to `onItemSelected`.
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final isSelected = activeIndex == index;
              return GestureDetector(
                onTap: () => onItemSelected(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _items[index]['icon'] as IconData,
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : Colors.black38,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _items[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : Colors.black38,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 6 : 0,
                      height: isSelected ? 6 : 0,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
