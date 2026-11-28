import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/handovers/data/datasources/handover_api.dart';
import 'package:thuethietbi_app/features/handovers/data/models/handover_preparation.dart';

/// Bottom sheet quét mã vạch (Camera `mobile_scanner`) hoặc nhập tay Serial thiết bị.
/// Luôn hiển thị bước kiểm tra lại thông tin thiết bị trước khi xác nhận đưa vào phiếu
/// (vì định dạng serial trên tem thực tế có thể khác nhau).
class SerialBarcodeScannerSheet extends StatefulWidget {
  const SerialBarcodeScannerSheet({
    super.key,
    required this.api,
    required this.contractId,
    required this.contractItems,
    required this.alreadyPickedIds,
    required this.remainingByModelId,
  });

  final HandoverApi api;
  final String contractId;
  final List<PreparationItem> contractItems;
  final Set<String> alreadyPickedIds;
  final Map<String, int> remainingByModelId;

  static Future<({SerialLookupResult device, String? replacedForModelId})?> open(
    BuildContext context, {
    required HandoverApi api,
    required String contractId,
    required List<PreparationItem> contractItems,
    required Set<String> alreadyPickedIds,
    required Map<String, int> remainingByModelId,
  }) {
    return showModalBottomSheet<
      ({SerialLookupResult device, String? replacedForModelId})
    >(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SerialBarcodeScannerSheet(
        api: api,
        contractId: contractId,
        contractItems: contractItems,
        alreadyPickedIds: alreadyPickedIds,
        remainingByModelId: remainingByModelId,
      ),
    );
  }

  @override
  State<SerialBarcodeScannerSheet> createState() =>
      _SerialBarcodeScannerSheetState();
}

class _SerialBarcodeScannerSheetState extends State<SerialBarcodeScannerSheet> {
  final _serialCtrl = TextEditingController();
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _cameraEnabled = true;
  bool _torchOn = false;
  bool _lookingUp = false;
  String? _error;
  SerialLookupResult? _foundDevice;
  String? _selectedTargetModelId;

  @override
  void dispose() {
    _serialCtrl.dispose();
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _lookingUp) return;

    setState(() {
      _lookingUp = true;
      _error = null;
      _foundDevice = null;
      _selectedTargetModelId = null;
      _serialCtrl.text = code;
    });

    try {
      final res = await widget.api.lookupSerial(
        serial: code,
        contractId: widget.contractId,
      );
      if (!mounted) return;

      if (widget.alreadyPickedIds.contains(res.equipmentId)) {
        setState(() {
          _error = 'Thiết bị ${res.serialNumber} đã có trong phiếu bàn giao này rồi.';
        });
        return;
      }

      if (!res.isAvailableForHandover) {
        setState(() {
          _error = res.unavailableReason ??
              'Thiết bị ${res.serialNumber} hiện không sẵn sàng để xuất kho.';
        });
        return;
      }

      // Nếu không thuộc model trong hợp đồng → mặc định chọn model đầu tiên còn thiếu để thay thế
      String? defaultSubTarget;
      if (!res.isContractModel) {
        for (final item in widget.contractItems) {
          if ((widget.remainingByModelId[item.equipmentModelId] ?? 0) > 0) {
            defaultSubTarget = item.equipmentModelId;
            break;
          }
        }
        defaultSubTarget ??= widget.contractItems.isNotEmpty
            ? widget.contractItems.first.equipmentModelId
            : null;
      }

      setState(() {
        _foundDevice = res;
        _selectedTargetModelId = defaultSubTarget;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(
            e,
            fallback: 'Không tra cứu được mã serial "$code".',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _confirmAndAdd() {
    final dev = _foundDevice;
    if (dev == null) return;

    if (dev.isContractModel) {
      final rem = widget.remainingByModelId[dev.equipmentModelId] ?? 0;
      if (rem <= 0) {
        setState(() {
          _error =
              'Model ${dev.modelName} đã chọn đủ số lượng theo hợp đồng. Nếu muốn dùng thay thế cho model khác, vui lòng kiểm tra lại.';
        });
        return;
      }
      Navigator.pop(context, (device: dev, replacedForModelId: null));
    } else {
      if (_selectedTargetModelId == null) {
        setState(() {
          _error = 'Vui lòng chọn model trong hợp đồng cần thay thế.';
        });
        return;
      }
      final rem = widget.remainingByModelId[_selectedTargetModelId!] ?? 0;
      if (rem <= 0) {
        setState(() {
          _error = 'Model được chọn thay thế đã đủ số lượng theo hợp đồng.';
        });
        return;
      }
      Navigator.pop(
        context,
        (device: dev, replacedForModelId: _selectedTargetModelId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dev = _foundDevice;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quét Barcode / Nhập Serial',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _cameraEnabled ? 'Tắt camera' : 'Bật camera',
                    onPressed: () =>
                        setState(() => _cameraEnabled = !_cameraEnabled),
                    icon: Icon(
                      _cameraEnabled
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_outlined,
                    ),
                  ),
                  if (_cameraEnabled)
                    IconButton(
                      tooltip: 'Đèn flash',
                      onPressed: () async {
                        await _scannerCtrl.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                      icon: Icon(
                        _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_cameraEnabled) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 185,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _scannerCtrl,
                          onDetect: (capture) {
                            final barcodes = capture.barcodes;
                            if (barcodes.isEmpty) return;
                            final raw = barcodes.first.rawValue;
                            if (raw != null && raw.trim().isNotEmpty) {
                              _lookup(raw);
                            }
                          },
                        ),
                        Center(
                          child: Container(
                            width: 220,
                            height: 90,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2.2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _serialCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _lookup,
                      decoration: InputDecoration(
                        labelText: 'Mã Serial thiết bị',
                        hintText: 'Quét hoặc nhập tay rồi bấm Kiểm tra...',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _lookingUp
                        ? null
                        : () => _lookup(_serialCtrl.text),
                    child: _lookingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kiểm tra'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (dev != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dev.isContractModel
                        ? AppColors.successLight.withValues(alpha: 0.6)
                        : AppColors.warningLight.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: dev.isContractModel
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            dev.isContractModel
                                ? Icons.check_circle_rounded
                                : Icons.swap_horiz_rounded,
                            color: dev.isContractModel
                                ? AppColors.success
                                : AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dev.isContractModel
                                  ? 'Xác nhận đúng Model trong hợp đồng'
                                  : 'Thiết bị thuộc Model khác → Đề xuất thay thế',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: dev.isContractModel
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Serial: ${dev.serialNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text('Model thực tế: ${dev.modelName} (${dev.modelCode})'),
                      Text('Kho: ${dev.warehouseName} • Tình trạng: ${dev.condition}'),
                      if (!dev.isContractModel) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Chọn model trong hợp đồng được thay thế (giữ nguyên đơn giá gốc):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedTargetModelId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: [
                            for (final item in widget.contractItems)
                              DropdownMenuItem(
                                value: item.equipmentModelId,
                                child: Text(
                                  '${item.modelName} (còn thiếu ${widget.remainingByModelId[item.equipmentModelId] ?? 0}/${item.quantity})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedTargetModelId = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: dev.isContractModel
                                ? AppColors.primary
                                : AppColors.warning,
                          ),
                          onPressed: _confirmAndAdd,
                          icon: const Icon(Icons.add_task_rounded),
                          label: Text(
                            dev.isContractModel
                                ? 'Xác nhận bỏ vào phiếu'
                                : 'Đưa vào mục Đề xuất thay thế',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
