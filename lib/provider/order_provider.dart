import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/app_notification.dart';
import '../model/escrow_payment.dart';
import '../model/order_item.dart';
import 'notification_provider.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({required NotificationProvider notificationProvider})
      : _notificationProvider = notificationProvider {
    _seedOrders();
  }

  NotificationProvider _notificationProvider;
  final List<SellerOrder> _orders = [];
  final Random _random = Random();

  List<SellerOrder> get orders =>
      _orders.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get activeOrders => _orders
      .where((order) => order.status.index < OrderStatus.completed.index)
      .length;

  double get payoutsOnHold => _orders
      .where((order) =>
          order.status == OrderStatus.awaitingPayment ||
          order.status == OrderStatus.escrowFunded ||
          order.status == OrderStatus.delivered)
      .fold(0, (sum, order) => sum + order.total);

  double get payoutsReady => _orders
      .where((order) => order.status == OrderStatus.completed)
      .fold(0, (sum, order) => sum + order.total);

  SellerOrder? findById(String id) {
    try {
      return _orders.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  void _seedOrders() {
    final samples = [
      SellerOrder.seed(
        status: OrderStatus.awaitingPayment,
        productTitle: 'Wholesale Rice 25kg',
        price: 78000,
        buyerName: 'Alice',
        image:
            'https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=400&q=80',
      ),
      SellerOrder.seed(
        status: OrderStatus.escrowFunded,
        productTitle: 'Designer Kitenge Dress',
        price: 95000,
        buyerName: 'Neema',
        image:
            'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=400&q=80',
      ),
      SellerOrder.seed(
        status: OrderStatus.preparingShipment,
        productTitle: 'Kikapu ya Kariakoo',
        price: 45000,
        buyerName: 'Musa',
        image:
            'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?auto=format&fit=crop&w=400&q=80',
      ),
    ];
    _orders
      ..clear()
      ..addAll(samples);
  }

  void updateNotificationProvider(NotificationProvider provider) {
    _notificationProvider = provider;
  }

  Future<void> simulateIncomingOrder() async {
    const dataset = [
      {
        'title': 'Fresh Tilapia Pack',
        'image':
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
        'price': 62000
      },
      {
        'title': 'Premium Coffee Beans',
        'image':
            'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400&q=80',
        'price': 38000
      },
      {
        'title': 'Leather Sandals',
        'image':
            'https://images.unsplash.com/photo-1475180098004-ca77a66827be?auto=format&fit=crop&w=400&q=80',
        'price': 55000
      },
    ];
    final payload = dataset[_random.nextInt(dataset.length)];
    final price = (payload['price'] as num).toDouble();
    final newOrder = SellerOrder.seed(
      status: OrderStatus.awaitingPayment,
      productTitle: payload['title']! as String,
      price: price,
      buyerName: 'Alice',
      image: payload['image']! as String,
    );
    _orders.insert(0, newOrder);
    _notificationProvider.push(
      AppNotification(
        id: const Uuid().v4(),
        type: NotificationType.order,
        title: 'New order awaiting payment',
        message:
            '${newOrder.buyer.name} placed ${newOrder.product.title}. Await escrow funding.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> progressOrder(String orderId) async {
    final index = _orders.indexWhere((element) => element.id == orderId);
    if (index == -1) return;
    final current = _orders[index];
    final nextStatus = _nextStatus(current.status);
    final updatedEscrow = _mapStatusToEscrow(current.escrow, nextStatus);
    final updatedTimeline = [
      OrderTimelineEntry(
        title: orderStatusLabel(nextStatus),
        description: _generateTimelineMessage(nextStatus),
        timestamp: DateTime.now(),
        isCompleted: true,
      ),
      ...current.timeline,
    ];
    final updatedOrder = current.copyWith(
      status: nextStatus,
      escrow: updatedEscrow,
      timeline: updatedTimeline,
      updatedAt: DateTime.now(),
      hasUnreadUpdates: true,
    );
    _orders[index] = updatedOrder;
    _notificationProvider.push(
      AppNotification(
        id: const Uuid().v4(),
        type: NotificationType.order,
        title: 'Order ${updatedOrder.orderNumber}',
        message: _notificationMessageForStatus(updatedOrder),
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> submitProofOfDelivery(String orderId) async {
    final index = _orders.indexWhere((element) => element.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    final escrow = order.escrow.copyWith(
      proofOfDeliveryReceived: true,
      events: [
        EscrowEvent(
          title: 'Proof of delivery uploaded',
          message: '${order.product.title} proof shared with Kariakoo team.',
          timestamp: DateTime.now(),
        ),
        ...order.escrow.events,
      ],
    );
    _orders[index] = order.copyWith(
      escrow: escrow,
      status: OrderStatus.delivered,
      hasUnreadUpdates: true,
      updatedAt: DateTime.now(),
    );
    _notificationProvider.push(
      AppNotification(
        id: const Uuid().v4(),
        type: NotificationType.payment,
        title: 'Delivery proof submitted',
        message: 'Team Kariakoo will review and release funds once confirmed.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> openDispute(String orderId, String reason) async {
    final index = _orders.indexWhere((element) => element.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    final escrow = order.escrow.copyWith(
      state: EscrowState.disputeOpened,
      events: [
        EscrowEvent(
          title: 'Dispute opened',
          message: reason,
          timestamp: DateTime.now(),
        ),
        ...order.escrow.events,
      ],
    );
    _orders[index] = order.copyWith(
      status: OrderStatus.disputed,
      escrow: escrow,
      hasUnreadUpdates: true,
    );
    _notificationProvider.push(
      AppNotification(
        id: const Uuid().v4(),
        type: NotificationType.payment,
        title: 'Dispute in review',
        message:
            'Kariakoo team is reviewing your evidence for ${order.orderNumber}.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void markUpdatesAsRead(String orderId) {
    final index = _orders.indexWhere((element) => element.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(hasUnreadUpdates: false);
    notifyListeners();
  }

  OrderStatus _nextStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return OrderStatus.escrowFunded;
      case OrderStatus.escrowFunded:
        return OrderStatus.preparingShipment;
      case OrderStatus.preparingShipment:
        return OrderStatus.outForDelivery;
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
      case OrderStatus.delivered:
        return OrderStatus.completed;
      case OrderStatus.completed:
        return OrderStatus.completed;
      case OrderStatus.disputed:
        return OrderStatus.disputed;
      case OrderStatus.cancelled:
        return OrderStatus.cancelled;
    }
  }

  EscrowPayment _mapStatusToEscrow(EscrowPayment escrow, OrderStatus status) {
    final state = () {
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
    }();

    final event = EscrowEvent(
      title: orderStatusLabel(status),
      message: _generateTimelineMessage(status),
      timestamp: DateTime.now(),
    );
    return escrow.copyWith(
      state: state,
      events: [event, ...escrow.events],
      proofOfPaymentReceived: true,
    );
  }

  String _generateTimelineMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return 'Waiting for buyer to complete payment.';
      case OrderStatus.escrowFunded:
        return 'Escrow funded. Prepare the package.';
      case OrderStatus.preparingShipment:
        return 'Package is being prepared for pickup.';
      case OrderStatus.outForDelivery:
        return 'Rider picked up your package.';
      case OrderStatus.delivered:
        return 'Delivery proof submitted. Awaiting buyer confirmation.';
      case OrderStatus.completed:
        return 'Payment released to your wallet.';
      case OrderStatus.disputed:
        return 'Kariakoo team reviewing dispute.';
      case OrderStatus.cancelled:
        return 'Order was cancelled.';
    }
  }

  String _notificationMessageForStatus(SellerOrder order) {
    switch (order.status) {
      case OrderStatus.awaitingPayment:
        return '${order.buyer.name} is funding escrow.';
      case OrderStatus.escrowFunded:
        return 'Escrow funded for ${order.product.title}. Prepare shipment.';
      case OrderStatus.preparingShipment:
        return 'Package ${order.orderNumber} is being prepared.';
      case OrderStatus.outForDelivery:
        return 'Order ${order.orderNumber} is in transit.';
      case OrderStatus.delivered:
        return 'Awaiting buyer confirmation for ${order.product.title}.';
      case OrderStatus.completed:
        return 'Payment released for ${order.product.title}.';
      case OrderStatus.disputed:
        return 'Dispute opened on ${order.product.title}.';
      case OrderStatus.cancelled:
        return 'Order ${order.orderNumber} cancelled.';
    }
  }
}
