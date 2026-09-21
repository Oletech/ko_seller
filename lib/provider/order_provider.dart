import 'dart:async';

import 'package:flutter/material.dart';

import '../model/order_item.dart';
import '../model/product_item.dart';
import '../model/sales_record.dart';
import '../model/seller_profile.dart';
import '../services/marketplace_order_service.dart';
import 'notification_provider.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({
    required NotificationProvider notificationProvider,
    required MarketplaceOrderService remoteService,
  })  : _notificationProvider = notificationProvider,
        _remoteService = remoteService {
    _notificationProvider.addListener(_syncNotificationState);
  }

  NotificationProvider _notificationProvider;
  final MarketplaceOrderService _remoteService;
  final List<SellerOrder> _orders = [];
  StreamSubscription<List<SellerOrder>>? _ordersSubscription;

  SellerProfile? _seller;
  List<ProductItem> _sellerProducts = const [];
  bool _isLoading = false;
  String? _lastError;

  List<SellerOrder> get orders =>
      _orders.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  int get activeOrders =>
      _orders.where((order) => order.isOpenLifecycle).length;

  double get payoutsOnHold => _orders
      .where((order) =>
          order.status == OrderStatus.awaitingPayment ||
          order.status == OrderStatus.escrowFunded ||
          order.status == OrderStatus.preparingShipment ||
          order.status == OrderStatus.outForDelivery ||
          order.status == OrderStatus.delivered ||
          order.status == OrderStatus.disputed)
      .fold(0, (sum, order) => sum + order.total);

  double get payoutsReady => _orders
      .where((order) => order.status == OrderStatus.completed)
      .fold(0, (sum, order) => sum + order.total);

  List<SalesRecord> get weeklySalesRecords {
    final now = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index)),
    );

    return days.map((day) {
      final dayOrders = _orders.where((order) {
        final created = DateTime(
          order.createdAt.year,
          order.createdAt.month,
          order.createdAt.day,
        );
        return created == day;
      }).toList();

      final revenue = dayOrders.fold<double>(
        0,
        (sum, order) => sum + order.total,
      );
      final payoutReleased = dayOrders
          .where((order) => order.status == OrderStatus.completed)
          .fold<double>(0, (sum, order) => sum + order.total);
      final payoutOnHold = dayOrders
          .where((order) =>
              order.status != OrderStatus.completed &&
              order.status != OrderStatus.cancelled)
          .fold<double>(0, (sum, order) => sum + order.total);
      final unitsSold = dayOrders.fold<int>(
        0,
        (sum, order) => sum + order.quantity,
      );

      return SalesRecord(
        label: _weekdayLabel(day.weekday),
        revenue: revenue,
        payoutReleased: payoutReleased,
        payoutOnHold: payoutOnHold,
        orders: dayOrders.length,
        unitsSold: unitsSold,
        averageOrderValue:
            dayOrders.isEmpty ? 0 : revenue / dayOrders.length.toDouble(),
        trendPoints: [
          revenue,
          payoutReleased,
          payoutOnHold,
          unitsSold.toDouble(),
          dayOrders.length.toDouble(),
        ],
      );
    }).toList(growable: false);
  }

  SellerOrder? findById(String id) {
    try {
      return _orders.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> bindSellerContext(
    SellerProfile? seller,
    List<ProductItem> sellerProducts,
  ) async {
    final normalizedProducts = sellerProducts
        .map((product) => '${product.id}|${product.sku}')
        .toList(growable: false);
    final currentProducts = _sellerProducts
        .map((product) => '${product.id}|${product.sku}')
        .toList(growable: false);
    final sameSeller = _seller?.id == seller?.id &&
        _seller?.firestoreDocId == seller?.firestoreDocId;
    final sameProducts = normalizedProducts.length == currentProducts.length &&
        normalizedProducts.every(currentProducts.contains);

    if (sameSeller && sameProducts) {
      return;
    }

    await _ordersSubscription?.cancel();
    _ordersSubscription = null;

    _seller = seller;
    _sellerProducts = List<ProductItem>.from(sellerProducts);

    if (seller == null) {
      _orders.clear();
      _lastError = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    await _startWatchingOrders();
  }

  Future<void> refreshOrders() async {
    if (_seller == null) {
      _orders.clear();
      _lastError = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final remoteOrders = await _remoteService.fetchSellerOrders(
        seller: _seller!,
        sellerProducts: _sellerProducts,
      );
      _orders
        ..clear()
        ..addAll(remoteOrders);
      _applyNotificationState();
    } catch (_) {
      _lastError = 'Could not sync seller orders from Firestore.';
      _orders.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Escrow is funded and the item is ready for handoff.
  Future<bool> markPacked(String orderId) {
    return _runOrderAction(
      orderId,
      (docId) => _remoteService.markPacked(docId),
      'Could not mark this order as packed.',
    );
  }

  /// Item handed to a courier or on its way to the buyer.
  Future<bool> markInTransit(String orderId, {String location = ''}) {
    return _runOrderAction(
      orderId,
      (docId) => _remoteService.markInTransit(docId, location: location),
      'Could not mark this order as in transit.',
    );
  }

  /// Item delivered; starts the buyer confirmation / auto-release window.
  Future<bool> markDelivered(String orderId) {
    return _runOrderAction(
      orderId,
      (docId) => _remoteService.markDelivered(docId),
      'Could not mark this order as delivered.',
    );
  }

  /// Moves a funded order to its next fulfilment stage.
  Future<bool> progressOrder(String orderId) {
    final order = findById(orderId);
    if (order == null) return Future.value(false);
    switch (order.status) {
      case OrderStatus.escrowFunded:
        return markPacked(orderId);
      case OrderStatus.preparingShipment:
        return markInTransit(orderId);
      case OrderStatus.outForDelivery:
        return markDelivered(orderId);
      default:
        return Future.value(false);
    }
  }

  Future<bool> openDispute(String orderId, String reason) {
    return _runOrderAction(
      orderId,
      (docId) => _remoteService.requestReturnReview(
        orderDocumentId: docId,
        note: reason,
      ),
      'Could not submit this return review action.',
    );
  }

  Future<bool> approveRefund(String orderId, String note) {
    return _runOrderAction(
      orderId,
      (docId) => _remoteService.approveRefund(
        orderDocumentId: docId,
        note: note,
      ),
      'Could not approve refund for this order.',
    );
  }

  Future<bool> rejectReturn(String orderId, String note) {
    return _runOrderAction(
      orderId,
      (docId) => _remoteService.rejectReturn(
        orderDocumentId: docId,
        note: note,
      ),
      'Could not reject this return request.',
    );
  }

  Future<bool> _runOrderAction(
    String orderId,
    Future<void> Function(String orderDocumentId) action,
    String fallbackMessage,
  ) async {
    final order = findById(orderId);
    if (order == null || order.orderDocumentId.isEmpty) return false;
    _lastError = null;
    notifyListeners();
    try {
      await action(order.orderDocumentId);
      await refreshOrders();
      return true;
    } on MarketplaceOrderException catch (error) {
      _lastError = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _lastError = fallbackMessage;
      notifyListeners();
      return false;
    }
  }

  void updateNotificationProvider(NotificationProvider provider) {
    if (identical(_notificationProvider, provider)) {
      return;
    }
    _notificationProvider.removeListener(_syncNotificationState);
    _notificationProvider = provider;
    _notificationProvider.addListener(_syncNotificationState);
    _applyNotificationState();
  }

  Future<void> markUpdatesAsRead(String orderId) async {
    final order = findById(orderId);
    if (order == null) return;
    await _notificationProvider.markOrderNotificationsAsRead(
      orderId: order.id,
      orderDocumentId: order.orderDocumentId,
    );
  }

  int reservedUnitsForProduct(ProductItem product) {
    final reservedProductIds = <String>{
      product.id,
      product.sku,
    }..removeWhere((value) => value.isEmpty);

    return _orders
        .where(
          (order) =>
              order.isStockReserved &&
              reservedProductIds.contains(order.product.productId),
        )
        .fold<int>(0, (sum, order) => sum + order.quantity);
  }

  int availableUnitsForProduct(ProductItem product) {
    final available = product.stock - reservedUnitsForProduct(product);
    return available < 0 ? 0 : available;
  }

  Future<void> _startWatchingOrders() async {
    if (_seller == null) return;

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _ordersSubscription = _remoteService
          .watchSellerOrders(
        seller: _seller!,
        sellerProducts: _sellerProducts,
      )
          .listen(
        (remoteOrders) {
          _orders
            ..clear()
            ..addAll(remoteOrders);
          _applyNotificationState(notify: false);
          _isLoading = false;
          _lastError = null;
          notifyListeners();
        },
        onError: (_) {
          _lastError = 'Could not listen for seller order updates.';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (_) {
      _lastError = 'Could not start seller order sync.';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _syncNotificationState() {
    _applyNotificationState();
  }

  void _applyNotificationState({bool notify = true}) {
    var changed = false;
    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      final hasUnread = _notificationProvider.hasUnreadForOrder(
        orderId: order.id,
        orderDocumentId: order.orderDocumentId,
      );
      if (order.hasUnreadUpdates != hasUnread) {
        _orders[i] = order.copyWith(hasUnreadUpdates: hasUnread);
        changed = true;
      }
    }

    if (changed && notify) {
      notifyListeners();
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _notificationProvider.removeListener(_syncNotificationState);
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
