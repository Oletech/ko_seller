import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/product_item.dart';
import '../model/product_metrics.dart';
import '../services/local_storage_service.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({required LocalStorageService storage}) : _storage = storage {
    _loadProducts();
  }

  final LocalStorageService _storage;
  final List<ProductItem> _products = [];

  List<ProductItem> get products =>
      _products.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

  void _loadProducts() {
    final stored = _storage.readProducts();
    if (stored.isEmpty) {
      _products
        ..clear()
        ..addAll(_seedProducts());
      _persist();
    } else {
      _products
        ..clear()
        ..addAll(stored);
    }
    notifyListeners();
  }

  Future<void> addProduct(ProductItem product) async {
    final updated = product.copyWith(
      id: product.id.isEmpty ? const Uuid().v4() : product.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metrics: ProductMetrics.randomSeed(_products.length + 1),
    );
    _products.add(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> updateProduct(ProductItem product) async {
    final index = _products.indexWhere((element) => element.id == product.id);
    if (index == -1) return;
    _products[index] = product.copyWith(updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> togglePublish(String productId) async {
    final index = _products.indexWhere((element) => element.id == productId);
    if (index == -1) return;
    final current = _products[index];
    final newStatus = current.status == ProductStatus.published
        ? ProductStatus.draft
        : ProductStatus.published;
    _products[index] = current.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removeProduct(String productId) async {
    _products.removeWhere((element) => element.id == productId);
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
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.saveProducts(_products);
  }

  List<ProductItem> _seedProducts() {
    final now = DateTime.now();
    return [
      ProductItem(
        id: const Uuid().v4(),
        title: 'Kikapu ya Kariakoo',
        category: 'Food',
        description:
            'Fresh Kariakoo market grocery combo with vegetables and spices.',
        price: 45000,
        stock: 24,
        media: const [
          'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?auto=format&fit=crop&w=400&q=80'
        ],
        allowNegotiation: true,
        status: ProductStatus.published,
        metrics: ProductMetrics.randomSeed(3),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      ProductItem(
        id: const Uuid().v4(),
        title: 'Designer Kitenge Dress',
        category: 'Fashion',
        description:
            'Handmade kitenge dress tailored for Kariakoo online audience.',
        price: 95000,
        stock: 12,
        media: const [
          'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=400&q=80'
        ],
        allowNegotiation: false,
        status: ProductStatus.published,
        metrics: ProductMetrics.randomSeed(5),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      ProductItem(
        id: const Uuid().v4(),
        title: 'Wholesale Rice 25kg',
        category: 'Groceries',
        description:
            'Premium Tanzanian rice in 25kg bags for wholesale customers.',
        price: 78000,
        stock: 40,
        media: const [
          'https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=400&q=80'
        ],
        allowNegotiation: true,
        status: ProductStatus.published,
        metrics: ProductMetrics.randomSeed(7),
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }
}
