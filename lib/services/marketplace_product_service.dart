import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../model/product_item.dart';
import '../model/product_metrics.dart';
import '../model/seller_profile.dart';
import 'firebase_storage_upload_exception.dart';
import 'firebase_session_service.dart';

class MarketplaceProductService {
  MarketplaceProductService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    required FirebaseSessionService sessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _sessionService = sessionService;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseSessionService _sessionService;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Future<List<ProductItem>> fetchSellerProducts(SellerProfile seller) async {
    await _sessionService.ensureSignedIn();
    final sellerIds = seller.productSellerIds;
    if (sellerIds.isEmpty) return const [];

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    if (sellerIds.length == 1) {
      final snapshot =
          await _products.where('seller.id', isEqualTo: sellerIds.first).get();
      docs.addAll(snapshot.docs);
    } else {
      final snapshot =
          await _products.where('seller.id', whereIn: sellerIds).get();
      docs.addAll(snapshot.docs);
    }

    final uniqueDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in docs) {
      uniqueDocs[doc.id] = doc;
    }

    final products = uniqueDocs.values.map(_toProductItem).toList();
    products.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return products;
  }

  Future<ProductItem> createProduct({
    required ProductItem product,
    required SellerProfile seller,
  }) async {
    await _sessionService.ensureSignedIn();
    final doc = _products.doc();
    final sku = product.sku.isEmpty ? _buildSku() : product.sku;
    final images = await _resolveImageUrls(sku, product.media);
    final now = DateTime.now();
    final normalized = product.copyWith(
      id: doc.id,
      sku: sku,
      media: images,
      createdAt: now,
      updatedAt: now,
    );

    await doc.set(
      _buildDocument(
        product: normalized,
        seller: seller,
        imageUrls: images,
        firestoreId: doc.id,
        isUpdate: false,
      ),
    );

    return normalized;
  }

  Future<ProductItem> updateProduct({
    required ProductItem product,
    required SellerProfile seller,
  }) async {
    await _sessionService.ensureSignedIn();
    if (product.id.isEmpty) {
      throw StateError('Cannot update a product without a Firestore id.');
    }

    final sku = product.sku.isEmpty ? _buildSku() : product.sku;
    final images = await _resolveImageUrls(sku, product.media);
    final normalized = product.copyWith(
      sku: sku,
      media: images,
      updatedAt: DateTime.now(),
    );

    await _products.doc(product.id).set(
          _buildDocument(
            product: normalized,
            seller: seller,
            imageUrls: images,
            firestoreId: product.id,
            isUpdate: true,
          ),
          SetOptions(merge: true),
        );

    return normalized;
  }

  Future<void> setProductStatus(
    String firestoreId,
    ProductStatus status,
  ) async {
    await _sessionService.ensureSignedIn();
    final moderationFields = _sellerModerationFields(status);
    await _products.doc(firestoreId).set(
      {
        ...moderationFields,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateStock(String firestoreId, int stock) async {
    await _sessionService.ensureSignedIn();
    await _products.doc(firestoreId).set(
      {
        'color': _buildColorData(stock),
        'stock': stock,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> removeProduct(String firestoreId) async {
    await _sessionService.ensureSignedIn();
    await _products.doc(firestoreId).delete();
  }

  ProductItem _toProductItem(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final images = _extractImages(data);
    final releaseDate = _asDateTime(data['releaseDate']);
    final updatedAt = _asDateTime(data['updatedAt'], fallback: releaseDate);

    return ProductItem(
      id: doc.id,
      sku: '${data['productId'] ?? ''}',
      title: '${data['productName'] ?? ''}',
      category: '${data['categoryName'] ?? 'General'}',
      description: '${data['productDescriptions'] ?? ''}',
      price: _asDouble(data['priceTo'] ?? data['price']),
      purchaseMode: '${data['purchaseMode'] ?? 'retail'}',
      unitPrice: _asDouble(data['unitPrice'] ?? data['price']),
      availableForRetail: data['availableForRetail'] as bool? ?? true,
      availableForWholesale: data['availableForWholesale'] as bool? ?? false,
      retailPrice: _asDouble(data['retailPrice'] ?? data['price']),
      wholesalePrice: _asDouble(data['wholesalePrice']),
      wholesaleMinQty: _asInt(data['wholesaleMinQty']) ?? 1,
      stock: _asInt(data['stock']) ?? _extractStock(data['color']),
      media: images,
      allowNegotiation: data['allowNegotiation'] as bool? ?? false,
      status: _resolveStatus(data),
      metrics: const ProductMetrics(),
      createdAt: releaseDate,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> _buildDocument({
    required ProductItem product,
    required SellerProfile seller,
    required List<String> imageUrls,
    required String firestoreId,
    required bool isUpdate,
  }) {
    final ownerUid = _sessionService.currentUser?.uid ?? '';
    final sellerName = seller.storeName.trim().isNotEmpty
        ? seller.storeName.trim()
        : seller.displayName.trim().isNotEmpty
            ? seller.displayName.trim()
            : seller.phoneNumber;
    final category = product.category.trim().isEmpty
        ? 'General'
        : product.category.trim();
    final productName = product.title.trim();
    final description = product.description.trim();
    final basePrice = product.displayPrice;
    final lowestPrice = product.lowestPrice > 0 ? product.lowestPrice : basePrice;
    final highestPrice =
        product.highestPrice > 0 ? product.highestPrice : basePrice;
    final priceValue = _formatPrice(basePrice);
    final moderationFields = _sellerModerationFields(product.status);

    return {
      'productId': product.sku.isEmpty ? _buildSku() : product.sku,
      'productName': productName,
      'categoryName': category,
      'productDescriptions': description,
      'price': priceValue,
      'priceFrom': _formatPrice(lowestPrice),
      'priceTo': _formatPrice(highestPrice),
      'purchaseMode': product.normalizedPurchaseMode,
      'unitPrice': basePrice,
      'availableForRetail': product.availableForRetail,
      'availableForWholesale': product.availableForWholesale,
      'retailPrice': product.availableForRetail ? product.retailPrice : 0,
      'wholesalePrice':
          product.availableForWholesale ? product.wholesalePrice : 0,
      'wholesaleMinQty':
          product.availableForWholesale ? product.wholesaleMinQty : 1,
      'color': _buildColorData(product.stock),
      'image': imageUrls.isEmpty ? 'null' : imageUrls.first,
      'gallery': imageUrls,
      'offers': {
        'type': 'Offer',
        'priceCurrency': 'TZS',
        'price': priceValue,
        'priceValidUntil': '0000-00-00',
      },
      'availability': moderationFields['availability'],
      'priceCurrency': 'TZS',
      'seller': {
        'id': seller.productSellerId,
        'firestoreDocId': seller.firestoreDocId,
        'ownerUid': ownerUid,
        'type': seller.businessType.trim().isEmpty
            ? 'null'
            : seller.businessType.trim(),
        'name': sellerName,
      },
      'min_order':
          product.availableForWholesale && !product.availableForRetail
              ? product.wholesaleMinQty
              : 1,
      'approved': moderationFields['approved'],
      'firestore_id': firestoreId,
      'sellerStatus': moderationFields['sellerStatus'],
      'moderationStatus': moderationFields['moderationStatus'],
      'allowNegotiation': product.allowNegotiation,
      'stock': product.stock,
      'updatedAt': FieldValue.serverTimestamp(),
      if (moderationFields['submittedAt'] != null)
        'submittedAt': moderationFields['submittedAt'],
      // Marketplace-owned counters and metadata are initialised once and
      // never reset by seller edits (review fields stay untouched too; the
      // rules reject writes that change them).
      if (!isUpdate) ...{
        'productCondition': 'new',
        'brand': 'null',
        'aggregateRating': {
          'type': 'AggregateRating',
          'ratingValue': '0',
          'reviewCount': '0',
        },
        'viewer': 0,
        'num_order': 0,
        'material': '',
        'hotdeal': false,
        'releaseDate': FieldValue.serverTimestamp(),
      },
    };
  }

  Future<List<String>> _resolveImageUrls(
    String productId,
    List<String> sources,
  ) async {
    final urls = <String>[];

    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      if (source.startsWith('http')) {
        urls.add(source);
        continue;
      }

      final file = File(source);
      if (!file.existsSync()) continue;

      final ref = _storage.ref().child(
            'product_images/$productId/${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
          );
      try {
        await ref.putFile(file);
        urls.add(await ref.getDownloadURL());
      } catch (error) {
        throw mapFirebaseStorageUploadException(error);
      }
    }

    return urls;
  }

  Map<String, dynamic> _buildColorData(int stock) {
    return {
      '0': {
        '0': {
          'color': 'Default',
          'size': 'Default',
          'qty': '${stock < 0 ? 0 : stock}',
        },
      },
    };
  }

  Map<String, dynamic> _sellerModerationFields(ProductStatus status) {
    switch (status) {
      case ProductStatus.pending:
      case ProductStatus.published:
        return {
          'sellerStatus': 'pending',
          'moderationStatus': 'submitted',
          'approved': false,
          'availability': false,
          'submittedAt': FieldValue.serverTimestamp(),
        };
      case ProductStatus.archived:
        return {
          'sellerStatus': 'archived',
          'moderationStatus': 'archived',
          'approved': false,
          'availability': false,
        };
      case ProductStatus.draft:
        return {
          'sellerStatus': 'draft',
          'moderationStatus': 'draft',
          'approved': false,
          'availability': false,
        };
    }
  }

  List<String> _extractImages(Map<String, dynamic> data) {
    final gallery = data['gallery'];
    if (gallery is Iterable) {
      final urls = gallery
          .map((item) => '$item')
          .where((item) => item.isNotEmpty && item != 'null')
          .toList(growable: false);
      if (urls.isNotEmpty) return urls;
    }

    final image = '${data['image'] ?? ''}';
    if (image.isEmpty || image == 'null') return const [];
    return [image];
  }

  ProductStatus _resolveStatus(Map<String, dynamic> data) {
    final moderationStatus = '${data['moderationStatus'] ?? ''}'.trim();
    switch (moderationStatus) {
      case 'approved':
        return ProductStatus.published;
      case 'submitted':
        return ProductStatus.pending;
      case 'archived':
        return ProductStatus.archived;
      case 'rejected':
      case 'draft':
        return ProductStatus.draft;
    }

    final sellerStatus = data['sellerStatus'];
    if (sellerStatus is String) {
      return ProductStatus.values.firstWhere(
        (value) => value.name == sellerStatus,
        orElse: () => ProductStatus.draft,
      );
    }

    final approved = data['approved'] == true;
    final availability = data['availability'] == true;
    if (approved && availability) return ProductStatus.published;
    if (!approved && availability) return ProductStatus.pending;
    return ProductStatus.draft;
  }

  DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    }
    return fallback ?? DateTime.now();
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  int _extractStock(dynamic node) {
    if (node is Map) {
      if (node.containsKey('qty')) {
        return int.tryParse('${node['qty']}') ?? 0;
      }
      return node.values.fold<int>(
        0,
        (total, value) => total + _extractStock(value),
      );
    }

    if (node is Iterable) {
      return node.fold<int>(0, (total, value) => total + _extractStock(value));
    }

    return 0;
  }

  String _formatPrice(double price) {
    if (price <= 0) return '0.0';
    if (price == price.roundToDouble()) return price.toStringAsFixed(0);
    return price.toStringAsFixed(2);
  }

  String _buildSku() => 'sku${DateTime.now().microsecondsSinceEpoch}';
}
