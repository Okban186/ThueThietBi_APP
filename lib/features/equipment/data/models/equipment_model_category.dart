class EquipmentModelCategory {
  const EquipmentModelCategory({
    required this.equipmentModelId,
    required this.categoryId,
  });
  final String equipmentModelId, categoryId;
  factory EquipmentModelCategory.fromJson(Map<String, dynamic> json) =>
      EquipmentModelCategory(
        equipmentModelId: json['equipmentModelId'] as String,
        categoryId: json['categoryId'] as String,
      );
}
