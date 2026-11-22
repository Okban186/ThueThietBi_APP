/// Định dạng ngày giờ hiển thị bằng tiếng Việt.
abstract final class DateFormatter {
  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// Ví dụ: 03/11/2025
  static String date(DateTime value) {
    return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
  }

  /// Ví dụ: Thứ Hai, 03/11/2025
  static String weekdayDate(DateTime value) {
    return '${_weekdays[value.weekday - 1]}, ${date(value)}';
  }

  /// Ví dụ: 05/11/2025 – 10/11/2025
  static String dateRange(DateTime from, DateTime to) {
    return '${date(from)} – ${date(to)}';
  }

  /// Ví dụ: vừa xong, 5 phút trước, 2 giờ trước, 3 ngày trước, 03/11/2025
  static String relative(DateTime value, {DateTime? now}) {
    final difference = (now ?? DateTime.now()).difference(value);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'vừa xong';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    }

    return date(value);
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
