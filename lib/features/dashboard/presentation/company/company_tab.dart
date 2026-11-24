import 'package:flutter/material.dart';

/// Các tab chính của khách hàng doanh nghiệp (Bottom Navigation + Drawer).
enum CompanyTab {
  dashboard('Tổng quan', Icons.home_outlined, Icons.home_rounded),
  contracts('Hợp đồng', Icons.description_outlined, Icons.description_rounded),
  incidents('Sự cố', Icons.build_circle_outlined, Icons.build_circle_rounded),
  account('Tài khoản', Icons.person_outline_rounded, Icons.person_rounded);

  const CompanyTab(this.title, this.icon, this.selectedIcon);

  final String title;
  final IconData icon;
  final IconData selectedIcon;

  /// Các tab nghiệp vụ hiển thị trong Drawer (Tài khoản mở qua thẻ người dùng).
  static const drawerTabs = [dashboard, contracts, incidents];
}
