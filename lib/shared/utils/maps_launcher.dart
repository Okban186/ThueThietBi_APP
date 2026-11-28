import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tiện ích mở ứng dụng Google Maps chỉ đường theo từng chặng và gọi điện thoại nhanh.
abstract final class MapsLauncher {
  /// Mở Google Maps chỉ đường từ vị trí GPS hiện tại tới tọa độ (ưu tiên) hoặc địa chỉ văn bản.
  static Future<void> openDirections(
    BuildContext context, {
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    String? destination;
    if (latitude != null && longitude != null) {
      destination = '$latitude,$longitude';
    } else if (address != null && address.trim().isNotEmpty) {
      destination = address.trim();
    }

    if (destination == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có địa chỉ hoặc tọa độ để mở Google Maps.'),
          ),
        );
      }
      return;
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể mở ứng dụng bản đồ trên thiết bị này.'),
        ),
      );
    }
  }

  /// Mở ứng dụng gọi điện thoại.
  static Future<void> callPhone(BuildContext context, String? phone) async {
    final clean = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: clean);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gọi tới số $clean.')),
      );
    }
  }
}
