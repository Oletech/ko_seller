import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/product_item.dart';
import '../model/product_metrics.dart';
import '../model/seller_profile.dart';
import '../services/local_storage_service.dart';
import '../services/marketplace_product_service.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({
    required LocalStorageService storage,
    required MarketplaceProductService remoteService,
  })  : _storage = storage,
        _remoteService = remoteService {
    _loadLocalProducts();
  }

  final LocalStorageService _storage;
  final MarketplaceProductService _remoteService;
  final List<ProductItem> _products = [];
  SellerProfile? _seller;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _lastError;

  List<ProductItem> get products =>
      _products.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get lastError => _lastError;

  double get totalInventoryValue =>
      _products.fold(0, (sum, item) => sum + item.inventoryValue);

  int get totalUnits =>
      _products.fold(0, (sum, item) => sum + (item.stock < 0 ? 0 : item.stock));

  int get lowStockCount =>
      _products.where((element) => element.isLowStock).length;

  ProductItem? findById(String id) {
    return _products.cast<ProductItem?>().firstWhere(
          (element) => element?.id == id,
          orElse: () => null,
        );
  }

  Future<void> bindSeller(SellerProfile? seller) async {
    if (_seller?.id == seller?.id &&
        _seller?.firestoreDocId == seller?.firestoreDocId) {
      return;
    }
    _seller = seller;

    if (seller == null) {
      _lastError = null;
      _loadLocalProducts();
      return;
    }

    await refreshProducts();
  }

  Future<void> refreshProducts() async {
    if (_seller == null) {
      _loadLocalProducts();
      return;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final remoteProducts = await _remoteService.fetchSellerProducts(_seller!);
      _products
        ..clear()
        ..addAll(remoteProducts);
      await _persist();
    } catch (_) {
      _lastError = 'Could not sync products from Firestore.';
      _loadLocalProducts(notify: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadLocalProducts({bool notify = true}) {
    final stored = _storage.readProducts();
    _products
      ..clear()
      ..addAll(stored);
    if (notify) notifyListeners();
  }

  Future<void> addProduct(ProductItem product) async {
    if (_seller == null) {
      throw StateError('Please sign in again before posting products.');
    }

    final draft = product.copyWith(
      id: product.id.isEmpty ? const Uuid().v4() : product.id,
      sku: product.sku.isEmpty ? 'sku${DateTime.now().microsecondsSinceEpoch}' : product.sku,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metrics: ProductMetrics.randomSeed(_products.length + 1),
    );

    _isSaving = true;
    _lastError = null;
    notifyListeners();

    try {
      final saved = await _remoteService.createProduct(
        product: draft,
        seller: _seller!,
      );
      _products.add(saved);
      await _persist();
    } catch (_) {
      _lastError = 'Could not publish product. Please try again.';
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateProduct(ProductItem product) async {
    final index = _products.indexWhere((element) => element.id == product.id);
    if (index == -1) return;

    final updated = product.copyWith(updatedAt: DateTime.now());
    if (_seller != null && updated.id.isNotEmpty) {
      _products[index] = await _remoteService.updateProduct(
        product: updated,
        seller: _seller!,
      );
    } else {
      _products[index] = updated;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setStatus(String productId, ProductStatus status) async {
    final index = _products.indexWhere((element) => element.id == productId);
    if (index == -1) return;
    _products[index] = _products[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    if (_products[index].id.isNotEmpty) {
      await _remoteService.setProductStatus(_products[index].id, status);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeProduct(String productId) async {
    final removed = findById(productId);
    _products.removeWhere((element) => element.id == productId);
    if (removed != null && removed.id.isNotEmpty) {
      await _remoteService.removeProduct(removed.id);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateStock(String productId, int newStock) async {
    final index = _products.indexWhere((element) => element.id == productId);
    if (index == -1) return;
    _products[index] = _products[index].copyWith(
      stock: newStock,
      updatedAt: DateTime.now(),
    );
    if (_products[index].id.isNotEmpty) {
      await _remoteService.updateStock(_products[index].id, newStock);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.saveProducts(_products);
  }
}
