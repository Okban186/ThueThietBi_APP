import 'package:flutter/material.dart';

/// Đặt nội dung (trạng thái trống/lỗi) ở giữa nhưng vẫn cuộn được,
/// để `RefreshIndicator` hoạt động cả khi danh sách rỗng.
class AppScrollableCenter extends StatelessWidget {
  const AppScrollableCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
