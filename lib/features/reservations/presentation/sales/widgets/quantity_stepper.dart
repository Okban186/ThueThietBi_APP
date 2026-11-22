import 'package:flutter/material.dart';

/// Nút tăng/giảm số lượng trong khoảng [min, max].
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.enabled = true,
  });

  final int value;
  final int min;
  final int? max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = enabled && value > min;
    final canIncrease = enabled && (max == null || value < max!);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: canDecrease ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.outlined(
          onPressed: canIncrease ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
