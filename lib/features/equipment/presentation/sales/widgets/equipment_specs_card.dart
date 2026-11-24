import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

/// Thông số kỹ thuật (JSON lồng nhau) hiển thị theo nhóm, chỉ xem.
class EquipmentSpecsCard extends StatelessWidget {
  const EquipmentSpecsCard({super.key, required this.specifications});

  final Map<String, dynamic>? specifications;

  @override
  Widget build(BuildContext context) {
    final specs = specifications;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông số kỹ thuật',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (specs == null || specs.isEmpty)
            const Text(
              'Chưa cập nhật thông số kỹ thuật.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final entry in specs.entries)
              _SpecNode(label: entry.key, value: entry.value, depth: 0),
        ],
      ),
    );
  }
}

class _SpecNode extends StatelessWidget {
  const _SpecNode({
    required this.label,
    required this.value,
    required this.depth,
  });

  final String label;
  final dynamic value;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final title = _formatKey(label);
    final value = this.value;

    // Mảng ngắn chỉ gồm giá trị đơn: hiện trên một dòng.
    if (value is List && value.every((e) => e is! Map && e is! List)) {
      return _KeyValueRow(
        label: title,
        value: value.isEmpty ? '-' : value.map(_formatValue).join(', '),
        depth: depth,
      );
    }

    if (value is Map<String, dynamic> || value is List) {
      final children = value is Map<String, dynamic>
          ? [
              for (final e in value.entries)
                _SpecNode(label: e.key, value: e.value, depth: depth + 1),
            ]
          : [
              for (var i = 0; i < (value as List).length; i++)
                _SpecNode(
                  label: '#${i + 1}',
                  value: value[i],
                  depth: depth + 1,
                ),
            ];

      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: depth == 0 ? 13.5 : 12.5,
              color: depth == 0 ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      );

      if (depth > 0) {
        return Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: content,
        );
      }

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      );
    }

    return _KeyValueRow(label: title, value: _formatValue(value), depth: depth);
  }

  /// snake_case, kebab-case, camelCase → "Chữ đầu viết hoa", giữ nguyên từ viết HOA (USB, RAM).
  static String _formatKey(String rawKey) {
    final separated = rawKey
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
          (_) => ' ',
        )
        .trim();

    if (separated.isEmpty) return rawKey;

    final words = separated.split(RegExp(r'\s+'));

    return [
      for (var i = 0; i < words.length; i++)
        if (words[i].length > 1 && words[i] == words[i].toUpperCase())
          words[i]
        else if (i == 0)
          words[i][0].toUpperCase() + words[i].substring(1).toLowerCase()
        else
          words[i].toLowerCase(),
    ].join(' ');
  }

  static String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'Có' : 'Không';
    return value.toString();
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    required this.depth,
  });

  final String label, value;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final fontSize = depth == 0 ? 13.0 : 12.5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
