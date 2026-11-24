import 'package:flutter/material.dart';

enum StorekeeperTab {
  dashboard('Tổng quan', Icons.home_outlined, Icons.home_rounded),
  models('Model TB', Icons.category_outlined, Icons.category_rounded),
  equipments(
    'Thiết bị kho',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded,
  ),
  account('Tài khoản', Icons.person_outline_rounded, Icons.person_rounded);

  const StorekeeperTab(this.title, this.icon, this.selectedIcon);
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  static const drawerTabs = [dashboard, models, equipments];
}
