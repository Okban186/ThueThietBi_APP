import 'package:flutter/material.dart';
import 'package:thuethietbi_app/shared/widgets/shared_widgets_test_screen.dart';

import '../../features/auth/data/models/user.dart';

// Import các màn hình chính tương ứng tại đây.

class RoleHomeRouter extends StatelessWidget {
  const RoleHomeRouter({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final roles = user.roles
        .map((role) => role.code.trim().toUpperCase())
        .toSet();

    // if (roles.contains('ADMIN')) {
    //   return const AdminHomeScreen();
    // }

    // if (roles.contains('MANAGER')) {
    //   return const ManagerHomeScreen();
    // }

    // if (roles.contains('SALES')) {
    //   return const SalesHomeScreen();
    // }

    // if (roles.contains('STOREKEEPER')) {
    //   return const StorekeeperHomeScreen();
    // }

    // if (roles.contains('TECHNICIAN')) {
    //   return const TechnicianHomeScreen();
    // }

    // if (roles.contains('COMPANY')) {
    //   return const CompanyHomeScreen();
    // }

    return SharedWidgetsTestScreen();
  }
}
