import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'escrow_payment.dart';

enum OrderStatus {
  awaitingPayment,
  escrowFunded,
  preparingShipment,
  outForDelivery,
  delivered,
  completed,
  disputed,
  cancelled,
}

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.awaitingPayment:
      return 'Awaiting Payment';
    case OrderStatus.escrowFunded:
      return 'Paid & In Escrow';
    case OrderStatus.preparingShipment:
      return 'Preparing Shipment';
    case OrderStatus.outForDelivery:
      return 'Out for Delivery';
    case OrderStatus.delivered:
      return 'Delivered - Awaiting Release';
    case OrderStatus.completed:
      return 'Completed';
    case OrderStatus.disputed:
      return 'Dispute in Review';
    case OrderStatus.cancelled:
      return 'Cancelled';
  }
}

class BuyerInfo extends Equatable {
  final String userId;
  final String name;
  final String phone;
  final String avatar;

  const BuyerInfo({
    this.userId = '',
    required this.name,
    required this.phone,
    this.avatar = '',
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'phone': phone,
        'avatar': avatar,
      };

  factory BuyerInfo.fromJson(Map<String, dynamic> json) {
    return BuyerInfo(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [userId, name, phone, avatar];
}

class ProductSnapshot extends Equatable {
  final String productId;
  final String sellerId;
  final String title;
  final double price;
  final String image;

  const ProductSnapshot({
    required this.productId,
    this.sellerId = '',
    required this.title,
    required this.price,
    required this.image,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'sellerId': sellerId,
        'title': title,
        'price': price,
        'image': image,
      };

  factory ProductSnapshot.fromJson(Map<String, dynamic> json) {
    return ProductSnapshot(
      productId: json['productId'] as String? ?? '',
      sellerId: json['sellerId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      image: json['image'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [productId, sellerId, title, price, image];
}

class OrderTimelineEntry extends Equatable {
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isCompleted;

  const OrderTimelineEntry({
    required this.title,
    required this.description,
    required this.timestamp,
    this.isCompleted = true,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'isCompleted': isCompleted,
      };

  factory OrderTimelineEntry.fromJson(Map<String, dynamic> json) {
    return OrderTimelineEntry(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      isCompleted: json['isCompleted'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [title, description, timestamp, isCompleted];
}

class SellerOrder extends Equatable {
  final String id;
  final String orderDocumentId;
  final String orderNumber;
  final String invoiceNumber;
  final String trackNumber;
  final String deliveryMethod;
  final BuyerInfo buyer;
  final ProductSnapshot product;
  final int quantity;
  final OrderStatus status;
  final EscrowPayment escrow;
  final String shippingAddress;
  final List<OrderTimelineEntry> timeline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasUnreadUpdates;
  final bool isPaid;

  const SellerOrder({
    required this.id,
    this.orderDocumentId = '',
    required this.orderNumber,
    this.invoiceNumber = '',
    this.trackNumber = '',
    this.deliveryMethod = '',
    required this.buyer,
    required this.product,
    required this.quantity,
    required this.status,
    required this.escrow,
    required this.shippingAddress,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
    this.hasUnreadUpdates = false,
    this.isPaid = false,
  });

  double get total => product.price * quantity;

  bool get requiresAction =>
      status == OrderStatus.preparingShipment ||
      status == OrderStatus.outForDelivery ||
      status == OrderStatus.delivered ||
      status == OrderStatus.disputed;

  SellerOrder copyWith({
    String? id,
    String? orderDocumentId,
    String? orderNumber,
    String? invoiceNumber,
    String? trackNumber,
    String? deliveryMethod,
    BuyerInfo? buyer,
    ProductSnapshot? product,
    int? quantity,
    OrderStatus? status,
    EscrowPayment? escrow,
    String? shippingAddress,
    List<OrderTimelineEntry>? timeline,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasUnreadUpdates,
    bool? isPaid,
  }) {
    return SellerOrder(
      id: id ?? this.id,
      orderDocumentId: orderDocumentId ?? this.orderDocumentId,
      orderNumber: orderNumber ?? this.orderNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      trackNumber: trackNumber ?? this.trackNumber,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      buyer: buyer ?? this.buyer,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      escrow: escrow ?? this.escrow,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      timeline: timeline ?? this.timeline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasUnreadUpdates: hasUnreadUpdates ?? this.hasUnreadUpdates,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderDocumentId': orderDocumentId,
      'orderNumber': orderNumber,
      'invoiceNumber': invoiceNumber,
      'trackNumber': trackNumber,
      'deliveryMethod': deliveryMethod,
      'buyer': buyer.toJson(),
      'product': product.toJson(),
      'quantity': quantity,
      'status': status.name,
      'escrow': escrow.toJson(),
      'shippingAddress': shippingAddress,
      'timeline': timeline.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hasUnreadUpdates': hasUnreadUpdates,
      'isPaid': isPaid,
    };
  }

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    return SellerOrder(
      id: json['id'] as String,
      orderDocumentId: json['orderDocumentId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      trackNumber: json['trackNumber'] as String? ?? '',
      deliveryMethod: json['deliveryMethod'] as String? ?? '',
      buyer: BuyerInfo.fromJson(Map<String, dynamic>.from(json['buyer'] ?? {})),
      product: ProductSnapshot.fromJson(
          Map<String, dynamic>.from(json['product'] ?? {})),
      quantity: json['quantity'] as int? ?? 1,
      status: OrderStatus.values.firstWhere(
        (element) => element.name == json['status'],
        orElse: () => OrderStatus.awaitingPayment,
      ),
      escrow: EscrowPayment.fromJson(
          Map<String, dynamic>.from(json['escrow'] ?? {})),
      shippingAddress: json['shippingAddress'] as String? ?? '',
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .map((e) => OrderTimelineEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      hasUnreadUpdates: json['hasUnreadUpdates'] as bool? ?? false,
      isPaid: json['isPaid'] as bool? ?? false,
    );
  }

  static SellerOrder seed({
    OrderStatus status = OrderStatus.awaitingPayment,
    double price = 60000,
    int quantity = 1,
    required String productTitle,
    required String image,
    required String buyerName,
  }) {
    final now = DateTime.now();
    final orderNumber =
        '#KO-${now.millisecondsSinceEpoch.toString().substring(8)}';
    return SellerOrder(
      id: const Uuid().v4(),
      orderDocumentId: '',
      orderNumber: orderNumber,
      invoiceNumber: '',
      trackNumber: '',
      deliveryMethod: 'Pick up in store',
      buyer: BuyerInfo(name: buyerName, phone: '+255712000000'),
      product: ProductSnapshot(
        productId: const Uuid().v4(),
        sellerId: '',
        title: productTitle,
        price: price,
        image: image,
      ),
      quantity: quantity,
      status: status,
      escrow: EscrowPayment.seed(
        buyerName: buyerName,
        sellerName: 'Bob Seller',
        amount: price * quantity,
        state: status == OrderStatus.awaitingPayment
            ? EscrowState.awaitingFunding
            : EscrowState.funded,
      ),
      shippingAddress: 'Kariakoo, Ilala - Dar es Salaam',
      timeline: [
        OrderTimelineEntry(
          title: 'Order Created',
          description: 'Buyer placed an order via Kariakoo Online',
          timestamp: now.subtract(const Duration(minutes: 30)),
        ),
        OrderTimelineEntry(
          title: 'Waiting for Payment',
          description: 'Escrow will be funded once buyer pays',
          timestamp: now.subtract(const Duration(minutes: 10)),
          isCompleted: status != OrderStatus.awaitingPayment,
        ),
      ],
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now,
      hasUnreadUpdates: true,
      isPaid: status != OrderStatus.awaitingPayment,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderDocumentId,
        orderNumber,
        invoiceNumber,
        trackNumber,
        deliveryMethod,
        buyer,
        product,
        quantity,
        status,
        escrow,
        shippingAddress,
        timeline,
        createdAt,
        updatedAt,
        hasUnreadUpdates,
        isPaid,
      ];
}
