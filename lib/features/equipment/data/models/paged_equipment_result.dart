class PagedEquipmentResult {
  const PagedEquipmentResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<dynamic> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasMore;

  factory PagedEquipmentResult.fromJson(Map<String, dynamic> json) =>
      PagedEquipmentResult(
        items: (json['items'] as List<dynamic>? ?? const []).cast(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
        hasMore: json['hasMore'] as bool? ?? false,
      );
}
