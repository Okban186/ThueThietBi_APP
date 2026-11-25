import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';

/// Tải PDF về thư mục tạm rồi mở bằng ứng dụng đọc PDF của máy
/// (từ đó có thể in, lưu hoặc chia sẻ).
///
/// Trả về thông báo lỗi để hiển thị, hoặc `null` nếu mở thành công.
Future<String?> openPdf(
  String fileName,
  Future<Uint8List> Function() load,
) async {
  try {
    final bytes = await load();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path, type: 'application/pdf');

    if (result.type != ResultType.done) {
      return 'Không mở được file PDF. Hãy cài một ứng dụng đọc PDF (ví dụ Google Drive).';
    }

    return null;
  } catch (error) {
    return apiErrorMessage(error, fallback: 'Không tải được file PDF.');
  }
}
