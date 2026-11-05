import 'package:flutter/material.dart';

abstract final class AppColors {
  // Màu thương hiệu.
  static const primary = Color(0xFF1749A6);
  static const primaryDark = Color(0xFF103B88);
  static const primaryLight = Color(0xFFE5EEFF);

  // Nền và bề mặt.
  static const background = Color(0xFFF3F6FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF7F9FE);

  // Văn bản.
  static const textPrimary = Color(0xFF142B55);
  static const textSecondary = Color(0xFF647796);
  static const textDisabled = Color(0xFF9AAAC4);

  // Đường viền.
  static const border = Color(0xFFDCE5F5);

  // Trạng thái.
  static const success = Color(0xFF21865D);
  static const successLight = Color(0xFFE2F5EB);

  static const warning = Color(0xFFC98218);
  static const warningLight = Color(0xFFFFF1D9);

  static const error = Color(0xFFD63845);
  static const errorLight = Color(0xFFFFE9EC);

  static const info = Color(0xFF2866C7);
  static const infoLight = Color(0xFFE6EFFF);

  static const Color selectedBackground = Color(0xFFE8F0FF);
  static const Color danger = Color(0xFFDC2626);
}
