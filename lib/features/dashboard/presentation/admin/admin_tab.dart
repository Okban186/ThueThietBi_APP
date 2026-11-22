import 'package:flutter/material.dart';

/// Các tab chính của quản trị viên (ADMIN chỉ quản lý tài khoản và phân quyền).
enum AdminTab {
  dashboard('Tổng quan', Icons.home_outlined, Icons.home_rounded),
  users(
    'Tài khoản',
    Icons.manage_accounts_outlined,
    Icons.manage_accounts_rounded,
  ),
  profile('Cá nhân', Icons.person_outline_rounded, Icons.person_rounded);

  const AdminTab(this.title, this.icon, this.selectedIcon);

  final String title;
  final IconData icon;
  final IconData selectedIcon;

  /// Các tab hiển thị trong Drawer (Cá nhân mở qua thẻ người dùng).
  static const drawerTabs = [dashboard, users];
}
