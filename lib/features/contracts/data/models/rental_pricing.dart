/// Quy định thời gian thuê và cách chọn giá, khớp `RentalPricing` của Backend.
/// - Thuê tối thiểu [minRentalDays] ngày (tính cả ngày đầu và ngày cuối).
/// - Đến [shortTermMaxDays] ngày: ngắn hạn, giá ngày × số ngày.
/// - Trên [shortTermMaxDays] ngày: dài hạn, giá tháng × số tháng làm tròn lên.
/// Đơn giá theo giá niêm yết của model, Sales không sửa được.
abstract final class RentalPricing {
  static const minRentalDays = 3;
  static const shortTermMaxDays = 10;

  /// Số ngày thuê tính cả ngày đầu và ngày cuối.
  static int rentalDays(DateTime from, DateTime to) =>
      DateTime.utc(
        to.year,
        to.month,
        to.day,
      ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
      1;

  static bool isLongTerm(int days) => days > shortTermMaxDays;

  /// Đơn giá niêm yết tương ứng với số ngày thuê.
  static double unitPriceFor(
    int days,
    double dailyPrice,
    double monthlyPrice,
  ) => isLongTerm(days) ? monthlyPrice : dailyPrice;
}
