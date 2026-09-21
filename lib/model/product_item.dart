import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'product_metrics.dart';

enum ProductStatus { draft, pending, published, archived }

class ProductItem extends Equatable {
  final String id;
  final String sku;
  final String title;
  final String category;
  final String description;
  final double price;
  final String purchaseMode;
  final double unitPrice;
  final bool availableForRetail;
  final bool availableForWholesale;
  final double retailPrice;
  final double wholesalePrice;
  final int wholesaleMinQty;
  final int stock;
  final List<String> media;
  final bool allowNegotiation;
  final ProductStatus status;
  final ProductMetrics metrics;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductItem({
    required this.id,
    required this.sku,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.purchaseMode,
    required this.unitPrice,
    required this.availableForRetail,
    required this.availableForWholesale,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.wholesaleMinQty,
    required this.stock,
    required this.media,
    required this.allowNegotiation,
    required this.status,
    required this.metrics,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductItem.empty() {
    return ProductItem(
      id: const Uuid().v4(),
      sku: '',
      title: '',
      category: 'General',
      description: '',
      price: 0,
      purchaseMode: 'retail',
      unitPrice: 0,
      availableForRetail: true,
      availableForWholesale: false,
      retailPrice: 0,
      wholesalePrice: 0,
      wholesaleMinQty: 1,
      stock: 0,
      media: const [],
      allowNegotiation: false,
      status: ProductStatus.pending,
      metrics: const ProductMetrics(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  bool get isLowStock => stock <= 5;

  double get inventoryValue => displayPrice * stock;

  String get normalizedPurchaseMode {
    if (purchaseMode.trim().toLowerCase() == 'wholesale' &&
        availableForWholesale) {
      return 'wholesale';
    }
    if (availableForRetail) return 'retail';
    if (availableForWholesale) return 'wholesale';
    return 'retail';
  }

  double get displayPrice {
    if (availableForRetail && retailPrice > 0) return retailPrice;
    if (availableForWholesale && wholesalePrice > 0) return wholesalePrice;
    if (unitPrice > 0) return unitPrice;
    return price;
  }

  double get lowestPrice {
    final values = <double>[
      if (availableForRetail && retailPrice > 0) retailPrice,
      if (availableForWholesale && wholesalePrice > 0) wholesalePrice,
      if (unitPrice > 0) unitPrice,
      if (price > 0) price,
    ];
    if (values.isEmpty) return 0;
    values.sort();
    return values.first;
  }

  double get highestPrice {
    final values = <double>[
      if (availableForRetail && retailPrice > 0) retailPrice,
      if (availableForWholesale && wholesalePrice > 0) wholesalePrice,
      if (unitPrice > 0) unitPrice,
      if (price > 0) price,
    ];
    if (values.isEmpty) return 0;
    values.sort();
    return values.last;
  }

  ProductItem copyWith({
    String? id,
    String? sku,
    String? title,
    String? category,
    String? description,
    double? price,
    String? purchaseMode,
    double? unitPrice,
    bool? availableForRetail,
    bool? availableForWholesale,
    double? retailPrice,
    double? wholesalePrice,
    int? wholesaleMinQty,
    int? stock,
    List<String>? media,
    bool? allowNegotiation,
    ProductStatus? status,
    ProductMetrics? metrics,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      purchaseMode: purchaseMode ?? this.purchaseMode,
      unitPrice: unitPrice ?? this.unitPrice,
      availableForRetail: availableForRetail ?? this.availableForRetail,
      availableForWholesale:
          availableForWholesale ?? this.availableForWholesale,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinQty: wholesaleMinQty ?? this.wholesaleMinQty,
      stock: stock ?? this.stock,
      media: media ?? this.media,
      allowNegotiation: allowNegotiation ?? this.allowNegotiation,
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'title': title,
      'category': category,
      'description': description,
      'price': price,
      'purchaseMode': purchaseMode,
      'unitPrice': unitPrice,
      'availableForRetail': availableForRetail,
      'availableForWholesale': availableForWholesale,
      'retailPrice': retailPrice,
      'wholesalePrice': wholesalePrice,
      'wholesaleMinQty': wholesaleMinQty,
      'stock': stock,
      'media': media,
      'allowNegotiation': allowNegotiation,
      'status': status.name,
      'metrics': metrics.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'] as String,
      sku: json['sku'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      purchaseMode: json['purchaseMode'] as String? ?? 'retail',
      unitPrice:
          (json['unitPrice'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0,
      availableForRetail: json['availableForRetail'] as bool? ?? true,
      availableForWholesale: json['availableForWholesale'] as bool? ?? false,
      retailPrice:
          (json['retailPrice'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0,
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0,
      wholesaleMinQty: json['wholesaleMinQty'] as int? ?? 1,
      stock: json['stock'] as int? ?? 0,
      media: (json['media'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      allowNegotiation: json['allowNegotiation'] as bool? ?? false,
      status: ProductStatus.values.firstWhere(
        (element) => element.name == json['status'],
        orElse: () => ProductStatus.draft,
      ),
      metrics: ProductMetrics.fromJson(
        Map<String, dynamic>.from(json['metrics'] ?? {}),
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        sku,
        title,
        category,
        description,
        price,
        purchaseMode,
        unitPrice,
        availableForRetail,
        availableForWholesale,
        retailPrice,
        wholesalePrice,
        wholesaleMinQty,
        stock,
        media,
        allowNegotiation,
        status,
        metrics,
        createdAt,
        updatedAt,
      ];
}
