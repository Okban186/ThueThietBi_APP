import 'package:flutter/material.dart';

enum ManagerTab {
  dashboard('Tổng quan', Icons.home_outlined, Icons.home_rounded),
  contracts('Hợp đồng', Icons.description_outlined, Icons.description_rounded),
  schedule(
    'Lịch trình',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  incidents(
    'Sự cố',
    Icons.support_agent_outlined,
    Icons.support_agent_rounded,
  ),
  account('Tài khoản', Icons.person_outline_rounded, Icons.person_rounded);

  const ManagerTab(this.title, this.icon, this.selectedIcon);

  final String title;
  final IconData icon;
  final IconData selectedIcon;

  static const drawerTabs = [dashboard, contracts, schedule, incidents];
}
