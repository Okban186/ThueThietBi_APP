import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import 'navigation_item.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    assert(items.length >= 2);
    assert(currentIndex >= 0 && currentIndex < items.length);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5EBF5), width: 0.8)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: items.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item.icon, size: 21),
            activeIcon: Icon(item.selectedIcon ?? item.icon, size: 22),
            label: item.title,
          );
        }).toList(),

        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,

        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF64748B),

        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.8,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.8,
        ),

        showSelectedLabels: true,
        showUnselectedLabels: true,

        iconSize: 21,
      ),
    );
  }
}
