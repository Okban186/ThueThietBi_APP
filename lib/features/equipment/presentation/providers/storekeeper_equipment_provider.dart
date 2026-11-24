import 'package:flutter/foundation.dart' hide Category;
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/storagekeeper_equipment_api.dart';
import 'package:thuethietbi_app/features/equipment/data/models/category.dart';
import 'package:thuethietbi_app/features/equipment/data/models/warehouse.dart';

class StorekeeperEquipmentProvider extends ChangeNotifier {
  StorekeeperEquipmentProvider(this.api, {required this.isLeadStorekeeper});

  final StorekeeperEquipmentApi api;
  final bool isLeadStorekeeper;

  List<dynamic> models = [];
  List<dynamic> equipments = [];
  List<Category> categories = [];
  List<Warehouse> warehouses = [];

  bool isLoadingModels = false;
  bool isLoadingEquipments = false;
  bool isLoadingMoreEquipments = false;
  String? error;

  // State phân trang cho tab Thiết bị kho
  int _equipmentPage = 1;
  int equipmentsTotalCount = 0;
  bool equipmentsHasMore = false;
  String? _eqModelId;
  String? _eqWarehouseId;
  String? _eqStatus;
  String? _eqKeyword;

  Future<void> loadAll() async {
    await Future.wait([loadMetadata(), loadModels(), loadEquipments()]);
  }

  Future<void> loadMetadata() async {
    try {
      final results = await Future.wait([
        api.getCategories(),
        api.getWarehouses(),
      ]);
      categories = results[0] as List<Category>;
      warehouses = results[1] as List<Warehouse>;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadModels({
    String? keyword,
    String? categoryId,
    String? status,
  }) async {
    isLoadingModels = true;
    error = null;
    notifyListeners();
    try {
      models = (await api.getModels(
        keyword: keyword,
        categoryId: categoryId,
        status: status,
      )).cast();
    } catch (e) {
      error = apiErrorMessage(e, fallback: 'Không tải được danh sách model.');
    } finally {
      isLoadingModels = false;
      notifyListeners();
    }
  }

  /// Tải trang đầu tiên của tab Thiết bị kho (20 máy/trang).
  Future<void> loadEquipments({
    String? modelId,
    String? warehouseId,
    String? status,
    String? keyword,
  }) async {
    _eqModelId = modelId;
    _eqWarehouseId = warehouseId;
    _eqStatus = status;
    _eqKeyword = keyword;
    _equipmentPage = 1;

    isLoadingEquipments = true;
    error = null;
    notifyListeners();
    try {
      final res = await api.getEquipmentsPaged(
        modelId: modelId,
        warehouseId: warehouseId,
        status: status,
        keyword: keyword,
        page: 1,
        pageSize: 20,
      );
      equipments = List<dynamic>.from(res.items);
      equipmentsTotalCount = res.totalCount;
      equipmentsHasMore = res.hasMore;
    } catch (e) {
      error = apiErrorMessage(
        e,
        fallback: 'Không tải được danh sách thiết bị kho.',
      );
    } finally {
      isLoadingEquipments = false;
      notifyListeners();
    }
  }

  /// Tải trang tiếp theo khi cuộn tới đáy.
  Future<void> loadMoreEquipments() async {
    if (isLoadingEquipments || isLoadingMoreEquipments || !equipmentsHasMore) {
      return;
    }

    isLoadingMoreEquipments = true;
    notifyListeners();
    try {
      final nextPage = _equipmentPage + 1;
      final res = await api.getEquipmentsPaged(
        modelId: _eqModelId,
        warehouseId: _eqWarehouseId,
        status: _eqStatus,
        keyword: _eqKeyword,
        page: nextPage,
        pageSize: 20,
      );
      _equipmentPage = nextPage;
      equipments.addAll(res.items);
      equipmentsTotalCount = res.totalCount;
      equipmentsHasMore = res.hasMore;
    } catch (_) {
    } finally {
      isLoadingMoreEquipments = false;
      notifyListeners();
    }
  }
}
