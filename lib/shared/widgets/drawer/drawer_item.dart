import 'package:flutter/material.dart';

class DrawerItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool selected;

  const DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.selected = false,
  });
}
