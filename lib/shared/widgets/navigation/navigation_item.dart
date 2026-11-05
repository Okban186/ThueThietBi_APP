import 'package:flutter/material.dart';

class NavigationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String title;

  const NavigationItem({
    required this.icon,
    this.selectedIcon,
    required this.title,
  });
}
