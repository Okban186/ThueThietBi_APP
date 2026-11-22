import 'package:flutter/material.dart';

/// Các tab chính của nhân viên kinh doanh (Bottom Navigation + Drawer).
enum SalesTab {
  dashboard('Tổng quan', Icons.home_outlined, Icons.home_rounded),
  reservations(
    'Đặt thuê',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  customers('Khách hàng', Icons.business_outlined, Icons.business_rounded),
  contracts('Hợp đồng', Icons.description_outlined, Icons.description_rounded),
  account('Tài khoản', Icons.person_outline_rounded, Icons.person_rounded);

  const SalesTab(this.title, this.icon, this.selectedIcon);

  final String title;
  final IconData icon;
  final IconData selectedIcon;

  /// Các tab nghiệp vụ hiển thị trong Drawer (Tài khoản mở qua thẻ người dùng).
  static const drawerTabs = [dashboard, reservations, customers, contracts];
}
