import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/escrow_payment.dart';
import '../model/order_item.dart';
import '../model/product_item.dart';
import '../model/seller_profile.dart';
import 'firebase_session_service.dart';

class MarketplaceOrderService {
  MarketplaceOrderService({
    FirebaseFirestore? firestore,
    required FirebaseSessionService sessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _sessionService = sessionService;

  final FirebaseFirestore _firestore;
  final FirebaseSessionService _sessionService;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('order');

  Future<List<SellerOrder>> fetchSellerOrders({
    required SellerProfile seller,
    required List<ProductItem> sellerProducts,
  }) async {
    await _sessionService.ensureSignedIn();

    final sellerIds = seller.productSellerIds.toSet();
    final productIds = <String>{
      for (final product in sellerProducts) ...[
        if (product.id.isNotEmpty) product.id,
        if (product.sku.isNotEmpty) product.sku,
      ],
    };

    final snapshot =
        await _orders.orderBy('dateTime', descending: true).limit(200).get();
    final results = <SellerOrder>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final items = _extractItems(data['products']);
      for (final item in items) {
        if (!_matchesSeller(
          orderData: data,
          item: item,
          sellerIds: sellerIds,
          productIds: productIds,
        )) {
          continue;
        }

        results.add(_toSellerOrder(
          orderDocumentId: doc.id,
          orderData: data,
          item: item,
          seller: seller,
        ));
      }
    }

    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  Future<void> markOrderCollected(String orderDocumentId) async {
    await _sessionService.ensureSignedIn();
    await _orders.doc(orderDocumentId).update({
      'deliveryStatus.orderCollected.orderCollected': true,
      'deliveryStatus.orderCollected.timeCollected':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markOrderDelivered(String orderDocumentId) async {
    await _sessionService.ensureSignedIn();
    await _orders.doc(orderDocumentId).update({
      'deliveryStatus.orderDelivered.orderDeliver': true,
      'deliveryStatus.orderDelivered.timePlaced': FieldValue.serverTimestamp(),
      'delivered': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<Map<String, dynamic>> _extractItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.map(
              (key, value) => MapEntry('$key', value),
            ))
        .toList(growable: false);
  }

  bool _matchesSeller({
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> item,
    required Set<String> sellerIds,
    required Set<String> productIds,
  }) {
    final itemSellerIds = <String>{
      ..._stringCandidates(item['sellerid']),
      ..._stringCandidates(item['sellerId']),
      ..._nestedStringCandidates(item, ['seller', 'id']),
      ..._nestedStringCandidates(item, ['seller', 'sellerid']),
      ..._nestedStringCandidates(item, ['seller', 'firestoreDocId']),
      ..._nestedStringCandidates(orderData, ['seller', 'id']),
      ..._nestedStringCandidates(orderData, ['seller', 'sellerid']),
      ..._stringCandidates(orderData['sellerid']),
      ..._stringCandidates(orderData['sellerId']),
    };

    if (itemSellerIds.any(sellerIds.contains)) {
      return true;
    }

    final itemProductIds = <String>{
      ..._stringCandidates(item['id']),
      ..._stringCandidates(item['productId']),
      ..._stringCandidates(item['sku']),
    };

    return itemProductIds.any(productIds.contains);
  }

  SellerOrder _toSellerOrder({
    required String orderDocumentId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> item,
    required SellerProfile seller,
  }) {
    final createdAt = _asDateTime(orderData['dateTime']);
    final updatedAt = _asDateTime(
      orderData['updatedAt'],
      fallback: _asDateTime(orderData['deliveryDate'], fallback: createdAt),
    );
    final quantity = _asInt(item['qty'], fallback: 1);
    final price = _asDouble(item['price']);
    final paid = _isPaid(orderData['paid']);
    final status = _resolveStatus(orderData);
    final buyerId = '${orderData['userId'] ?? ''}'.trim();
    final buyerName = '${orderData['customerName'] ?? orderData['customer'] ?? buyerId}'
        .trim();
    final buyerPhone = _extractPhone(orderData);
    final sellerName = seller.storeName.trim().isNotEmpty
        ? seller.storeName.trim()
        : seller.displayName.trim().isNotEmpty
            ? seller.displayName.trim()
            : seller.phoneNumber;
    final productId = _firstNonEmpty([
      '${item['id'] ?? ''}',
      '${item['productId'] ?? ''}',
      '${item['sku'] ?? ''}',
    ]);
    final sellerId = _firstNonEmpty([
      ..._stringCandidates(item['sellerid']),
      ..._stringCandidates(item['sellerId']),
      ..._nestedStringCandidates(item, ['seller', 'id']),
      ..._nestedStringCandidates(item, ['seller', 'sellerid']),
      ..._nestedStringCandidates(item, ['seller', 'firestoreDocId']),
      seller.productSellerId,
    ]);

    return SellerOrder(
      id: '$orderDocumentId:$productId',
      orderDocumentId: orderDocumentId,
      orderNumber: '${orderData['orderNumber'] ?? orderDocumentId}',
      invoiceNumber: '${orderData['invoiceNumber'] ?? ''}',
      trackNumber: '${orderData['trackNumber'] ?? ''}',
      deliveryMethod: '${orderData['deliveryMethod'] ?? ''}',
      buyer: BuyerInfo(
        userId: buyerId,
        name: buyerName.isNotEmpty ? buyerName : 'Marketplace customer',
        phone: buyerPhone,
      ),
      product: ProductSnapshot(
        productId: productId,
        sellerId: sellerId,
        title: '${item['name'] ?? item['productName'] ?? 'Product'}',
        price: price,
        image: _firstNonEmpty([
          '${item['images'] ?? ''}',
          '${item['image'] ?? ''}',
        ]),
      ),
      quantity: quantity,
      status: status,
      escrow: EscrowPayment(
        id: orderDocumentId,
        buyerName: buyerName.isNotEmpty ? buyerName : 'Marketplace customer',
        sellerName: sellerName,
        amount: _asDouble(orderData['amount'], fallback: price * quantity),
        state: _statusToEscrow(status),
        proofOfDeliveryReceived: status.index >= OrderStatus.delivered.index,
        proofOfPaymentReceived: paid,
        events: _buildEscrowEvents(orderData, status, createdAt),
        createdAt: createdAt,
        resolvedAt:
            status == OrderStatus.completed || status == OrderStatus.delivered
                ? updatedAt
                : null,
      ),
      shippingAddress: _buildShippingAddress(orderData),
      timeline: _buildTimeline(orderData, status, createdAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
      hasUnreadUpdates: false,
      isPaid: paid,
    );
  }

  List<OrderTimelineEntry> _buildTimeline(
    Map<String, dynamic> orderData,
    OrderStatus status,
    DateTime createdAt,
  ) {
    final timeline = <OrderTimelineEntry>[
      OrderTimelineEntry(
        title: 'Order created',
        description: 'Buyer placed the order on Kariakoo Online.',
        timestamp: createdAt,
      ),
    ];

    if (_isPaid(orderData['paid'])) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Payment confirmed',
          description: 'Payment was recorded for this order.',
          timestamp: _asDateTime(orderData['paidAt'], fallback: createdAt),
        ),
      );
    }

    final collectedAt = _nestedDateTime(
      orderData,
      ['deliveryStatus', 'orderCollected', 'timeCollected'],
      fallback: createdAt,
    );
    if (_nestedBool(orderData, ['deliveryStatus', 'orderCollected', 'orderCollected'])) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Order collected',
          description: 'The package was collected from the seller.',
          timestamp: collectedAt,
        ),
      );
    }

    final onTheWay = _extractItems(
      _nested(orderData, ['deliveryStatus', 'orderOnTheWay']),
    );
    for (final stop in onTheWay) {
      timeline.add(
        OrderTimelineEntry(
          title: 'In transit',
          description:
              'Package reported at ${_firstNonEmpty(['${stop['location'] ?? ''}'])}',
          timestamp:
              _asDateTime(stop['timeOnLocation'], fallback: collectedAt),
        ),
      );
    }

    if (_nestedBool(orderData, ['deliveryStatus', 'orderDelivered', 'orderDeliver'])) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Delivered',
          description: 'Order was marked as delivered.',
          timestamp: _nestedDateTime(
            orderData,
            ['deliveryStatus', 'orderDelivered', 'timePlaced'],
            fallback: createdAt,
          ),
        ),
      );
    }

    if (orderData['orderCancel'] == true) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Order cancelled',
          description: 'This order was cancelled.',
          timestamp: _asDateTime(orderData['updatedAt'], fallback: createdAt),
        ),
      );
    }

    timeline.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return timeline;
  }

  List<EscrowEvent> _buildEscrowEvents(
    Map<String, dynamic> orderData,
    OrderStatus status,
    DateTime createdAt,
  ) {
    return _buildTimeline(orderData, status, createdAt)
        .map(
          (entry) => EscrowEvent(
            title: entry.title,
            message: entry.description,
            timestamp: entry.timestamp,
          ),
        )
        .toList(growable: false);
  }

  OrderStatus _resolveStatus(Map<String, dynamic> orderData) {
    final delivered = _nestedBool(
      orderData,
      ['deliveryStatus', 'orderDelivered', 'orderDeliver'],
    );
    final collected = _nestedBool(
      orderData,
      ['deliveryStatus', 'orderCollected', 'orderCollected'],
    );
    final onTheWay = _extractItems(
      _nested(orderData, ['deliveryStatus', 'orderOnTheWay']),
    ).isNotEmpty;

    if (orderData['orderCancel'] == true) {
      return OrderStatus.cancelled;
    }
    if (orderData['orderRefund'] == true || orderData['orderReturn'] == true) {
      return OrderStatus.disputed;
    }
    if (delivered) {
      return OrderStatus.delivered;
    }
    if (collected || onTheWay) {
      return OrderStatus.outForDelivery;
    }
    if (_isPaid(orderData['paid'])) {
      return OrderStatus.preparingShipment;
    }
    return OrderStatus.awaitingPayment;
  }

  EscrowState _statusToEscrow(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return EscrowState.awaitingFunding;
      case OrderStatus.escrowFunded:
      case OrderStatus.preparingShipment:
      case OrderStatus.outForDelivery:
        return EscrowState.funded;
      case OrderStatus.delivered:
        return EscrowState.awaitingBuyerConfirmation;
      case OrderStatus.completed:
        return EscrowState.releasedToSeller;
      case OrderStatus.disputed:
        return EscrowState.disputeOpened;
      case OrderStatus.cancelled:
        return EscrowState.refundedToBuyer;
    }
  }

  String _buildShippingAddress(Map<String, dynamic> orderData) {
    final deliveryAddress = orderData['deliveryAddress'];
    if (deliveryAddress is Map) {
      final parts = deliveryAddress.values
          .map((value) => '$value'.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }

    return _firstNonEmpty([
      '${orderData['deliveryMethod'] ?? ''}',
      '${orderData['shippingAddress'] ?? ''}',
      'Delivery details not specified',
    ]);
  }

  String _extractPhone(Map<String, dynamic> orderData) {
    final deliveryAddress = orderData['deliveryAddress'];
    if (deliveryAddress is Map) {
      return _firstNonEmpty([
        '${deliveryAddress['phone'] ?? ''}',
        '${deliveryAddress['phoneNumber'] ?? ''}',
      ]);
    }
    return '${orderData['phone'] ?? ''}'.trim();
  }

  Iterable<String> _stringCandidates(dynamic value) sync* {
    final raw = '$value'.trim();
    if (raw.isNotEmpty && raw != 'null') {
      yield raw;
    }
  }

  Iterable<String> _nestedStringCandidates(
    Map<String, dynamic> source,
    List<String> path,
  ) sync* {
    final value = _nested(source, path);
    yield* _stringCandidates(value);
  }

  dynamic _nested(Map<String, dynamic> source, List<String> path) {
    dynamic current = source;
    for (final segment in path) {
      if (current is Map) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  bool _nestedBool(Map<String, dynamic> source, List<String> path) {
    final value = _nested(source, path);
    return value == true;
  }

  DateTime _nestedDateTime(
    Map<String, dynamic> source,
    List<String> path, {
    DateTime? fallback,
  }) {
    return _asDateTime(_nested(source, path), fallback: fallback);
  }

  bool _isPaid(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    final raw = '$value'.trim().toLowerCase();
    return raw.isNotEmpty && raw != 'false' && raw != 'null' && raw != '0';
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    }
    return fallback ?? DateTime.now();
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && trimmed != 'null') {
        return trimmed;
      }
    }
    return '';
  }
}
