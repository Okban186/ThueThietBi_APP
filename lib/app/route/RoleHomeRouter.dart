import 'package:flutter/material.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/admin/admin_main_layout.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/company/company_main_layout.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/manager/manager_main_layout.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/sales/sales_main_layout.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/storekeeper/storekeeper_main_layout.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/technician/technician_main_layout.dart';
import 'package:thuethietbi_app/shared/widgets/shared_widgets_test_screen.dart';

import '../../features/auth/data/models/user.dart';

class RoleHomeRouter extends StatelessWidget {
  const RoleHomeRouter({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final roles = user.roles
        .map((role) => role.code.trim().toUpperCase())
        .toSet();

    if (roles.contains('ADMIN')) {
      return const AdminMainLayout();
    }

    if (roles.contains('MANAGER')) {
      return const ManagerMainLayout();
    }

    if (roles.contains('SALES')) {
      return const SalesMainLayout();
    }

    if (roles.contains('LEAD_STOREKEEPER') || roles.contains('STOREKEEPER')) {
      return StorekeeperMainLayout(
        isLeadStorekeeper: roles.contains('LEAD_STOREKEEPER'),
      );
    }

    if (roles.contains('TECHNICIAN')) {
      return const TechnicianMainLayout();
    }

    if (roles.contains('COMPANY')) {
      return const CompanyMainLayout();
    }

    return SharedWidgetsTestScreen();
  }
}
