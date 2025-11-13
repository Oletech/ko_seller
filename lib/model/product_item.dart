import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'product_metrics.dart';

enum ProductStatus { draft, published, archived }

class ProductItem extends Equatable {
  final String id;
  final String title;
  final String category;
  final String description;
  final double price;
  final int stock;
  final List<String> media;
  final bool allowNegotiation;
  final ProductStatus status;
  final ProductMetrics metrics;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
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
      title: '',
      category: 'General',
      description: '',
      price: 0,
      stock: 0,
      media: const [],
      allowNegotiation: false,
      status: ProductStatus.draft,
      metrics: const ProductMetrics(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  bool get isLowStock => stock <= 5;

  double get inventoryValue => price * stock;

  ProductItem copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    double? price,
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
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
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
      'title': title,
      'category': category,
      'description': description,
      'price': price,
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
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
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
        title,
        category,
        description,
        price,
        stock,
        media,
        allowNegotiation,
        status,
        metrics,
        createdAt,
        updatedAt,
      ];
}
