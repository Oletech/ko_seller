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
  }) : _remoteService = remoteService;

  final MarketplaceOrderService _remoteService;
  final List<SellerOrder> _orders = [];

  SellerProfile? _seller;
  List<ProductItem> _sellerProducts = const [];
  bool _isLoading = false;
  String? _lastError;

  List<SellerOrder> get orders =>
      _orders.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

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

  void updateNotificationProvider(NotificationProvider provider) {}

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

    _seller = seller;
    _sellerProducts = List<ProductItem>.from(sellerProducts);

    if (seller == null) {
      _orders.clear();
      _lastError = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    await refreshOrders();
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
    } catch (_) {
      _lastError = 'Could not sync seller orders from Firestore.';
      _orders.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> simulateIncomingOrder() async {
    await refreshOrders();
  }

  Future<void> markOrderCollected(String orderId) async {
    final order = findById(orderId);
    if (order == null || order.orderDocumentId.isEmpty) return;
    await _remoteService.markOrderCollected(order.orderDocumentId);
    await refreshOrders();
  }

  Future<void> submitProofOfDelivery(String orderId) async {
    final order = findById(orderId);
    if (order == null || order.orderDocumentId.isEmpty) return;
    await _remoteService.markOrderDelivered(order.orderDocumentId);
    await refreshOrders();
  }

  Future<void> progressOrder(String orderId) async {
    final order = findById(orderId);
    if (order == null) return;
    if (order.status == OrderStatus.awaitingPayment ||
        order.status == OrderStatus.preparingShipment) {
      await markOrderCollected(orderId);
      return;
    }
    if (order.status == OrderStatus.outForDelivery) {
      await submitProofOfDelivery(orderId);
      return;
    }
  }

  Future<void> openDispute(String orderId, String reason) async {
    _lastError = 'Dispute tools are not connected for this seller app yet.';
    notifyListeners();
  }

  void markUpdatesAsRead(String orderId) {}

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
}
