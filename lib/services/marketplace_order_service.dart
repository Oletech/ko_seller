import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../model/escrow_payment.dart';
import '../model/order_item.dart';
import '../model/product_item.dart';
import '../model/seller_profile.dart';
import 'firebase_session_service.dart';

/// Raised when the marketplace backend rejects a seller order action. The
/// message is safe to show to the seller.
class MarketplaceOrderException implements Exception {
  const MarketplaceOrderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads seller order projections (`seller_orders/{sellerId}/orders/*`, written
/// by the `syncSellerOrderProjection` Cloud Function) and performs every order
/// transition through Cloud Functions callables. The seller app never writes
/// to the `order` collection directly; Firestore rules forbid it.
class MarketplaceOrderService {
  MarketplaceOrderService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    required FirebaseSessionService sessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _sessionService = sessionService;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseSessionService _sessionService;

  static const String _fulfillmentCallable = 'updateSellerFulfillment';
  static const String _returnReviewCallable = 'sellerReviewReturn';

  Query<Map<String, dynamic>> _sellerOrderProjectionQuery(String ownerUid) {
    return _firestore
        .collectionGroup('orders')
        .where('sellerOwnerUid', isEqualTo: ownerUid)
        .limit(200);
  }

  Future<List<SellerOrder>> fetchSellerOrders({
    required SellerProfile seller,
    required List<ProductItem> sellerProducts,
  }) async {
    final user = await _sessionService.ensureSignedIn();
    final snapshot = await _sellerOrderProjectionQuery(user!.uid).get();
    return _mapProjectedSellerOrders(docs: snapshot.docs, seller: seller);
  }

  Stream<List<SellerOrder>> watchSellerOrders({
    required SellerProfile seller,
    required List<ProductItem> sellerProducts,
  }) async* {
    final user = await _sessionService.ensureSignedIn();
    yield* _sellerOrderProjectionQuery(user!.uid).snapshots().map(
          (snapshot) => _mapProjectedSellerOrders(
            docs: snapshot.docs,
            seller: seller,
          ),
        );
  }

  // ---------------------------------------------------------------- actions

  /// Seller has the item ready for handoff. Requires escrow to be funded.
  Future<void> markPacked(String orderDocumentId, {String note = ''}) {
    return _callFulfillment(orderDocumentId, 'packed', note: note);
  }

  /// Item handed to a courier or on its way to the buyer.
  Future<void> markInTransit(
    String orderDocumentId, {
    String location = '',
    String note = '',
  }) {
    return _callFulfillment(
      orderDocumentId,
      'in_transit',
      note: note,
      location: location,
    );
  }

  /// Item delivered. Starts the buyer confirmation / auto-release window.
  Future<void> markDelivered(String orderDocumentId, {String note = ''}) {
    return _callFulfillment(orderDocumentId, 'delivered', note: note);
  }

  Future<void> requestReturnReview({
    required String orderDocumentId,
    required String note,
  }) {
    return _callReturnReview(orderDocumentId, 'request', note);
  }

  Future<void> approveRefund({
    required String orderDocumentId,
    required String note,
  }) {
    return _callReturnReview(orderDocumentId, 'approve', note);
  }

  Future<void> rejectReturn({
    required String orderDocumentId,
    required String note,
  }) {
    return _callReturnReview(orderDocumentId, 'reject', note);
  }

  Future<void> _callFulfillment(
    String orderDocumentId,
    String action, {
    String note = '',
    String location = '',
  }) {
    return _call(_fulfillmentCallable, {
      'orderId': orderDocumentId,
      'action': action,
      if (note.trim().isNotEmpty) 'note': note.trim(),
      if (location.trim().isNotEmpty) 'location': location.trim(),
    });
  }

  Future<void> _callReturnReview(
    String orderDocumentId,
    String action,
    String note,
  ) {
    return _call(_returnReviewCallable, {
      'orderId': orderDocumentId,
      'action': action,
      'note': note.trim(),
    });
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    await _sessionService.ensureSignedIn();
    try {
      await _functions.httpsCallable(name).call<dynamic>(data);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      throw MarketplaceOrderException(
        message == null || message.isEmpty
            ? 'The marketplace rejected this action (${error.code}).'
            : message,
      );
    } on FirebaseSessionException catch (error) {
      throw MarketplaceOrderException(error.message);
    } catch (_) {
      throw MarketplaceOrderException(
        'Could not reach the marketplace. Check your connection and retry.',
      );
    }
  }

  // ---------------------------------------------------------------- mapping

  List<SellerOrder> _mapProjectedSellerOrders({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required SellerProfile seller,
  }) {
    final results = <SellerOrder>[];

    for (final doc in docs) {
      final data = doc.data();
      final orderData = _firstMap([data['rawOrder']]);
      final item = _firstMap([data['rawItem']]);
      if (orderData.isEmpty || item.isEmpty) {
        continue;
      }

      final orderDocumentId = _firstNonEmpty([
        '${data['orderDocumentId'] ?? ''}',
        '${orderData['id'] ?? ''}',
      ]);
      if (orderDocumentId.isEmpty) {
        continue;
      }

      orderData['id'] = orderDocumentId;
      results.add(_toSellerOrder(
        orderDocumentId: orderDocumentId,
        orderData: orderData,
        item: item,
        projectionSellerId: '${data['sellerId'] ?? ''}'.trim(),
        seller: seller,
      ));
    }

    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  SellerOrder _toSellerOrder({
    required String orderDocumentId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> item,
    required String projectionSellerId,
    required SellerProfile seller,
  }) {
    final createdAt = _asDateTime(
      orderData['dateTime'],
      fallback: _asDateTime(orderData['createdAt']),
    );
    final updatedAt = _asDateTime(
      orderData['updatedAt'],
      fallback: _asDateTime(orderData['deliveryDate'], fallback: createdAt),
    );
    final quantity = _asInt(item['qty'], fallback: 1);
    final price = _asDouble(item['price']);
    final paid = _hasPaymentConfirmed(orderData);
    final status = _resolveStatus(orderData);
    final paymentProof = _buildPaymentProof(orderData, paid: paid);
    final deliveryProof = _buildDeliveryProof(orderData, status: status);
    final buyerId = '${orderData['userId'] ?? ''}'.trim();
    final buyerName = _extractBuyerName(orderData, buyerId);
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
      projectionSellerId,
      ..._stringCandidates(item['sellerId']),
      ..._stringCandidates(item['sellerid']),
      ..._nestedStringCandidates(item, ['seller', 'id']),
      seller.productSellerId,
    ]);
    final sellerTotals = _firstMap([orderData['sellerTotals']]);
    final escrowAmount = sellerTotals.containsKey(sellerId)
        ? _asDouble(sellerTotals[sellerId], fallback: price * quantity)
        : _asDouble(item['lineTotal'], fallback: price * quantity);

    return SellerOrder(
      id: '$orderDocumentId:$productId',
      orderDocumentId: orderDocumentId,
      orderNumber: '${orderData['orderNumber'] ?? orderDocumentId}',
      invoiceNumber: '${orderData['invoiceNumber'] ?? ''}',
      trackNumber: '${orderData['trackNumber'] ?? ''}',
      deliveryMethod: '${orderData['deliveryMethod'] ?? ''}',
      buyer: BuyerInfo(
        userId: buyerId,
        name: buyerName,
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
        buyerName: buyerName,
        sellerName: sellerName,
        amount: escrowAmount,
        state: _statusToEscrow(status),
        proofOfDeliveryReceived:
            deliveryProof.status == OrderProofStatus.verified ||
                deliveryProof.status == OrderProofStatus.submitted,
        proofOfPaymentReceived:
            paymentProof.status == OrderProofStatus.verified ||
                paymentProof.status == OrderProofStatus.submitted,
        events: _buildEscrowEvents(orderData, status, createdAt),
        createdAt: createdAt,
        resolvedAt: status == OrderStatus.completed
            ? (_tryDateTime(orderData['escrowReleasedAt']) ??
                _tryDateTime(orderData['payoutReleasedAt']) ??
                updatedAt)
            : null,
      ),
      paymentProof: paymentProof,
      deliveryProof: deliveryProof,
      shippingAddress: _buildShippingAddress(orderData),
      timeline: _buildTimeline(orderData, status, createdAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
      paymentExpiresAt: _tryDateTime(orderData['paymentExpiresAt']),
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

    if (_hasPaymentConfirmed(orderData)) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Escrow funded',
          description:
              'Buyer payment was confirmed and funds are held while you prepare delivery.',
          timestamp: _asDateTime(
            orderData['escrowHeldAt'],
            fallback: _asDateTime(orderData['paidAt'], fallback: createdAt),
          ),
        ),
      );
    } else if (status == OrderStatus.awaitingPayment) {
      final expiresAt = _tryDateTime(orderData['paymentExpiresAt']);
      timeline.add(
        OrderTimelineEntry(
          title: 'Waiting for payment',
          description:
              'Do not dispatch before escrow is funded. The buyer\'s payment link expires automatically.',
          timestamp: expiresAt ?? createdAt,
          isCompleted: false,
        ),
      );
    }

    final packedAt = _tryDateTime(orderData['packedAt']) ??
        _nestedTryDateTime(
          orderData,
          ['deliveryStatus', 'orderCollected', 'timeCollected'],
        );
    if (packedAt != null || status.index >= OrderStatus.preparingShipment.index &&
            status != OrderStatus.disputed &&
            status != OrderStatus.cancelled) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Packed',
          description: 'The item was prepared for handoff.',
          timestamp: packedAt ?? createdAt,
          isCompleted: packedAt != null,
        ),
      );
    }

    final inTransitAt = _tryDateTime(orderData['inTransitAt']);
    final onTheWay = _inTransitEntries(orderData);
    if (inTransitAt != null || onTheWay.isNotEmpty) {
      if (onTheWay.isEmpty) {
        timeline.add(
          OrderTimelineEntry(
            title: 'In transit',
            description: 'Package is on its way to the buyer.',
            timestamp: inTransitAt ?? createdAt,
          ),
        );
      }
      for (final stop in onTheWay) {
        timeline.add(
          OrderTimelineEntry(
            title: 'In transit',
            description: 'Package reported at ${stop['location']}',
            timestamp: _asDateTime(
              stop['timeOnLocation'],
              fallback: inTransitAt ?? createdAt,
            ),
          ),
        );
      }
    }

    final deliveredAt = _tryDateTime(orderData['deliveredAt']) ??
        _nestedTryDateTime(
          orderData,
          ['deliveryStatus', 'orderDelivered', 'timeofDeliver'],
        ) ??
        _nestedTryDateTime(
          orderData,
          ['deliveryStatus', 'orderDelivered', 'timePlaced'],
        );
    if (deliveredAt != null ||
        status == OrderStatus.delivered ||
        status == OrderStatus.completed) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Delivered',
          description: orderData['buyerConfirmedDelivery'] == true
              ? 'Buyer confirmed the delivery.'
              : 'Order was marked delivered. Awaiting buyer confirmation or the release window.',
          timestamp: deliveredAt ?? createdAt,
        ),
      );
    }

    if (status == OrderStatus.disputed) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Under review',
          description: _reviewDescription(orderData),
          timestamp: _tryDateTime(orderData['returnRequestedAt']) ??
              _tryDateTime(orderData['refundRequestedAt']) ??
              _tryDateTime(orderData['disputedAt']) ??
              _asDateTime(orderData['updatedAt'], fallback: createdAt),
          isCompleted: false,
        ),
      );
    }

    if (status == OrderStatus.cancelled) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Order cancelled',
          description: 'This order was cancelled.',
          timestamp: _tryDateTime(orderData['canceledAt']) ??
              _asDateTime(orderData['updatedAt'], fallback: createdAt),
        ),
      );
    }

    if (status == OrderStatus.completed) {
      timeline.add(
        OrderTimelineEntry(
          title: 'Payout released',
          description: 'Marketplace released the escrow payout to you.',
          timestamp: _tryDateTime(orderData['escrowReleasedAt']) ??
              _tryDateTime(orderData['payoutReleasedAt']) ??
              _asDateTime(orderData['updatedAt'], fallback: createdAt),
        ),
      );
    }

    timeline.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return timeline;
  }

  String _reviewDescription(Map<String, dynamic> orderData) {
    final refundStatus = _normalize(orderData['refundStatus']);
    final disputeStatus = _normalize(orderData['disputeStatus']);
    final returnStatus = _normalize(orderData['returnStatus']);
    if (disputeStatus == 'open') {
      return 'A dispute is open with the marketplace.';
    }
    if (refundStatus == 'sellerapproved') {
      return 'Refund approved. The marketplace will process it.';
    }
    if (refundStatus == 'requested') {
      return 'The buyer requested a refund.';
    }
    if (returnStatus == 'requested') {
      return 'The buyer requested a return.';
    }
    if (returnStatus == 'sellerrequested') {
      return 'You opened a return review.';
    }
    return 'Escrow is on hold while the return or refund is reviewed.';
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

  /// Canonical marketplace fields first (`paymentStatus`, `escrowStatus`,
  /// `fulfillmentStatus`), legacy booleans as a fallback for old orders.
  OrderStatus _resolveStatus(Map<String, dynamic> orderData) {
    final paymentStatus = _normalize(orderData['paymentStatus']);
    final escrowStatus = _normalize(orderData['escrowStatus']);
    final fulfillment = _normalize(orderData['fulfillmentStatus']);
    final payoutStatus = _normalize(orderData['sellerPayoutStatus']);

    if (orderData['orderCancel'] == true ||
        paymentStatus == 'canceled' ||
        fulfillment == 'canceled') {
      return OrderStatus.cancelled;
    }
    if (paymentStatus == 'releasedtoseller' ||
        escrowStatus == 'released' ||
        payoutStatus == 'released' ||
        _isLegacyCompleted(orderData)) {
      return OrderStatus.completed;
    }
    if (paymentStatus == 'disputed' ||
        paymentStatus == 'refundpending' ||
        paymentStatus == 'refunded' ||
        escrowStatus == 'disputed' ||
        escrowStatus == 'refundpending' ||
        escrowStatus == 'refunded' ||
        orderData['orderReturn'] == true ||
        orderData['orderRefund'] == true) {
      return OrderStatus.disputed;
    }
    if (!_hasPaymentConfirmed(orderData)) {
      return OrderStatus.awaitingPayment;
    }

    switch (fulfillment) {
      case 'delivered':
        return OrderStatus.delivered;
      case 'intransit':
        return OrderStatus.outForDelivery;
      case 'packed':
        return OrderStatus.preparingShipment;
    }

    if (_nestedBool(
        orderData, ['deliveryStatus', 'orderDelivered', 'orderDeliver'])) {
      return OrderStatus.delivered;
    }
    if (_inTransitEntries(orderData).isNotEmpty) {
      return OrderStatus.outForDelivery;
    }
    if (_nestedBool(
        orderData, ['deliveryStatus', 'orderCollected', 'orderCollected'])) {
      return OrderStatus.preparingShipment;
    }
    return OrderStatus.escrowFunded;
  }

  EscrowState _statusToEscrow(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return EscrowState.awaitingFunding;
      case OrderStatus.escrowFunded:
        return EscrowState.funded;
      case OrderStatus.preparingShipment:
      case OrderStatus.outForDelivery:
        return EscrowState.awaitingDelivery;
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

  bool _hasPaymentConfirmed(Map<String, dynamic> orderData) {
    final paymentStatus = _normalize(orderData['paymentStatus']);
    final escrowStatus = _normalize(orderData['escrowStatus']);
    if (paymentStatus == 'escrowheld' ||
        paymentStatus == 'releasedtoseller' ||
        escrowStatus == 'held' ||
        escrowStatus == 'releasepending' ||
        escrowStatus == 'released') {
      return true;
    }
    if (paymentStatus == 'awaitingpayment' ||
        paymentStatus == 'paymentprocessing' ||
        paymentStatus == 'expired') {
      return false;
    }
    return _isTruthy(orderData['paid']) ||
        _isTruthy(orderData['paymentConfirmed']) ||
        _isTruthy(orderData['escrowFunded']);
  }

  bool _isLegacyCompleted(Map<String, dynamic> orderData) {
    return _isTruthy(orderData['completed']) ||
        _isTruthy(orderData['orderCompleted']) ||
        _isTruthy(orderData['payoutReleased']) ||
        _isTruthy(orderData['escrowReleased']);
  }

  List<Map<String, dynamic>> _inTransitEntries(Map<String, dynamic> orderData) {
    final raw = _nested(orderData, ['deliveryStatus', 'orderOnTheWay']);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
        .where((entry) => '${entry['location'] ?? ''}'.trim().isNotEmpty &&
            '${entry['location']}' != 'null')
        .toList(growable: false);
  }

  String _extractBuyerName(Map<String, dynamic> orderData, String buyerId) {
    final shipping = _firstMap([orderData['shippingAddress']]);
    final billing = _firstMap([orderData['billingAddress']]);
    final delivery = _firstMap([orderData['deliveryAddress']]);
    final name = _firstNonEmpty([
      '${orderData['customerName'] ?? ''}',
      '${orderData['customer'] ?? ''}',
      '${orderData['buyerName'] ?? ''}',
      for (final source in [delivery, shipping, billing]) ...[
        '${source['name'] ?? ''}',
        '${source['fullName'] ?? ''}',
        '${source['fname'] ?? ''}',
      ],
    ]);
    return name.isNotEmpty ? name : 'Marketplace customer';
  }

  String _buildShippingAddress(Map<String, dynamic> orderData) {
    for (final key in ['deliveryAddress', 'shippingAddress', 'billingAddress']) {
      final address = orderData[key];
      if (address is Map) {
        final parts = address.entries
            .where((entry) => !{'phone', 'phoneNumber', 'email', 'name', 'fname'}
                .contains('${entry.key}'))
            .map((entry) => '${entry.value}'.trim())
            .where((value) => value.isNotEmpty && value != 'null')
            .toList();
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    }

    return _firstNonEmpty([
      '${orderData['deliveryMethod'] ?? ''}',
      '${orderData['shippingAddress'] ?? ''}',
      'Delivery details not specified',
    ]);
  }

  String _extractPhone(Map<String, dynamic> orderData) {
    for (final key in ['deliveryAddress', 'shippingAddress', 'billingAddress']) {
      final address = orderData[key];
      if (address is Map) {
        final phone = _firstNonEmpty([
          '${address['phone'] ?? ''}',
          '${address['phoneNumber'] ?? ''}',
        ]);
        if (phone.isNotEmpty) return phone;
      }
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
    yield* _stringCandidates(_nested(source, path));
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
    return _nested(source, path) == true;
  }

  DateTime? _nestedTryDateTime(
    Map<String, dynamic> source,
    List<String> path,
  ) {
    return _tryDateTime(_nested(source, path));
  }

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    final raw = '$value'.trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  OrderProof _buildPaymentProof(
    Map<String, dynamic> orderData, {
    required bool paid,
  }) {
    final raw = _firstMap([
      orderData['paymentProof'],
      orderData['proofOfPayment'],
      orderData['paymentReceipt'],
    ]);
    final reference = _firstNonEmpty([
      '${raw['reference'] ?? ''}',
      '${raw['transactionId'] ?? ''}',
      '${orderData['paymentSessionId'] ?? ''}',
      '${orderData['paymentReference'] ?? ''}',
      '${orderData['transactionId'] ?? ''}',
    ]);
    final note = _firstNonEmpty([
      '${raw['note'] ?? ''}',
      '${raw['message'] ?? ''}',
      if (paid) 'Paid via ${orderData['paymentProvider'] ?? 'escrow'}',
    ]);
    final assetUrl = _firstNonEmpty([
      '${raw['url'] ?? ''}',
      '${raw['imageUrl'] ?? ''}',
      '${orderData['paymentProofUrl'] ?? ''}',
    ]);
    final verifiedAt = _tryDateTime(orderData['paidAt']) ??
        _tryDateTime(orderData['escrowHeldAt']);
    final rejected = _normalize(orderData['paymentStatus']) == 'expired';

    return OrderProof(
      label: 'Payment proof',
      status: paid
          ? OrderProofStatus.verified
          : rejected
              ? OrderProofStatus.rejected
              : OrderProofStatus.missing,
      reference: reference,
      note: note,
      assetUrl: assetUrl,
      submittedAt: _tryDateTime(orderData['paymentInitiatedAt']),
      verifiedAt: verifiedAt,
    );
  }

  OrderProof _buildDeliveryProof(
    Map<String, dynamic> orderData, {
    required OrderStatus status,
  }) {
    final raw = _firstMap([
      orderData['deliveryProof'],
      orderData['proofOfDelivery'],
      _nested(orderData, ['deliveryStatus', 'orderDelivered', 'proof']),
    ]);
    final reference = _firstNonEmpty([
      '${raw['reference'] ?? ''}',
      '${raw['otp'] ?? ''}',
      '${raw['deliveryCode'] ?? ''}',
      '${orderData['trackNumber'] ?? ''}',
    ]);
    final note = _firstNonEmpty([
      '${raw['note'] ?? ''}',
      '${raw['message'] ?? ''}',
      '${orderData['sellerFulfillmentNote'] ?? ''}',
    ]);
    final assetUrl = _firstNonEmpty([
      '${raw['url'] ?? ''}',
      '${raw['imageUrl'] ?? ''}',
      '${raw['photoUrl'] ?? ''}',
      '${orderData['deliveryProofUrl'] ?? ''}',
    ]);
    final submittedAt = _tryDateTime(orderData['deliveredAt']) ??
        _nestedTryDateTime(
          orderData,
          ['deliveryStatus', 'orderDelivered', 'timeofDeliver'],
        ) ??
        _nestedTryDateTime(
          orderData,
          ['deliveryStatus', 'orderDelivered', 'timePlaced'],
        );
    final buyerConfirmed = orderData['buyerConfirmedDelivery'] == true;
    final verifiedAt = buyerConfirmed
        ? (_tryDateTime(orderData['buyerConfirmedDeliveryAt']) ?? submittedAt)
        : status == OrderStatus.completed
            ? (_tryDateTime(orderData['escrowReleasedAt']) ?? submittedAt)
            : null;
    final submitted = status == OrderStatus.delivered ||
        status == OrderStatus.completed ||
        submittedAt != null;

    return OrderProof(
      label: 'Delivery proof',
      status: buyerConfirmed || status == OrderStatus.completed
          ? OrderProofStatus.verified
          : submitted
              ? OrderProofStatus.submitted
              : OrderProofStatus.missing,
      reference: reference,
      note: note,
      assetUrl: assetUrl,
      submittedAt: submittedAt,
      verifiedAt: verifiedAt,
    );
  }

  Map<String, dynamic> _firstMap(List<dynamic> values) {
    for (final value in values) {
      if (value is Map) {
        return value.map((key, value) => MapEntry('$key', value));
      }
    }
    return const {};
  }

  String _normalize(dynamic value) {
    if (value == null) return '';
    return '$value'.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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
    return _tryDateTime(value) ?? fallback ?? DateTime.now();
  }

  DateTime? _tryDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['_seconds'] is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        ((value['_seconds'] as num) * 1000).toInt(),
      );
    }
    return null;
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
