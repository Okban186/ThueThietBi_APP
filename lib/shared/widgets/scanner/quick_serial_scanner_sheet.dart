import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';

/// Bottom sheet quét mã vạch/QR (Camera `mobile_scanner`) hoặc nhập tay số Serial thiết bị.
/// Dùng chung cho KTV (báo máy lỗi khi bàn giao) và Khách hàng (báo sự cố máy đang thuê).
class QuickSerialScannerSheet extends StatefulWidget {
  const QuickSerialScannerSheet({
    super.key,
    this.title = 'Quét mã vạch / Nhập Serial',
    this.subtitle = 'Đưa mã vạch trên tem thiết bị vào khung camera hoặc nhập mã ở bên dưới.',
  });

  final String title;
  final String subtitle;

  static Future<String?> open(
    BuildContext context, {
    String title = 'Quét mã vạch / Nhập Serial',
    String subtitle =
        'Đưa mã vạch trên tem thiết bị vào khung camera hoặc nhập mã ở bên dưới.',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => QuickSerialScannerSheet(
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<QuickSerialScannerSheet> createState() =>
      _QuickSerialScannerSheetState();
}

class _QuickSerialScannerSheetState extends State<QuickSerialScannerSheet> {
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manualCtrl = TextEditingController();
  bool _torchOn = false;
  bool _handled = false;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _returnSerial(String raw) {
    final code = raw.trim();
    if (code.isEmpty || _handled) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _torchOn ? 'Tắt đèn pin' : 'Bật đèn pin',
                  icon: Icon(
                    _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchOn ? AppColors.warning : AppColors.textSecondary,
                  ),
                  onPressed: () async {
                    await _scannerCtrl.toggleTorch();
                    if (mounted) setState(() => _torchOn = !_torchOn);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scannerCtrl,
                      onDetect: (capture) {
                        for (final b in capture.barcodes) {
                          final val = b.rawValue?.trim();
                          if (val != null && val.isNotEmpty) {
                            _returnSerial(val);
                            break;
                          }
                        }
                      },
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 220,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 2.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _returnSerial,
                    decoration: InputDecoration(
                      labelText: 'Hoặc nhập mã Serial thủ công',
                      hintText: 'VD: SN-SONY-001',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(84, 48),
                  ),
                  onPressed: () => _returnSerial(_manualCtrl.text),
                  child: const Text('Xác nhận'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
