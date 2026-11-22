/// Định dạng tiền Việt Nam đồng để hiển thị.
abstract final class CurrencyFormatter {
  /// Ví dụ: 32000000 → "32.000.000 đ"
  static String vnd(num amount) {
    final digits = amount.round().abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }

    return '${amount < 0 ? '-' : ''}$buffer đ';
  }
}
