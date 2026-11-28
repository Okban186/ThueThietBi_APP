import 'package:flutter/material.dart';

enum TechnicianTab {
  dashboard('Tổng quan', Icons.home_outlined, Icons.home_rounded),
  trips('Chuyến giao', Icons.local_shipping_outlined, Icons.local_shipping_rounded),
  maintenance('Bảo trì', Icons.build_outlined, Icons.build_rounded),
  incidents('Sự cố', Icons.support_agent_outlined, Icons.support_agent_rounded),
  account('Tài khoản', Icons.person_outline_rounded, Icons.person_rounded);

  const TechnicianTab(this.title, this.icon, this.selectedIcon);

  final String title;
  final IconData icon;
  final IconData selectedIcon;

  static const drawerTabs = [dashboard, trips, maintenance, incidents];
}
