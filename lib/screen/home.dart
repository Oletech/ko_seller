import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../model/app_notification.dart';
import '../model/order_item.dart';
import '../model/payment_channel.dart';
import '../model/seller_profile.dart';
import '../model/product_item.dart';
import '../model/sales_record.dart';
import '../model/seller_payout.dart';
import '../provider/auth_provider.dart';
import '../provider/notification_provider.dart';
import '../provider/order_provider.dart';
import '../provider/product_provider.dart';
import '../services/account_deletion_service.dart';
import '../services/firebase_session_service.dart';
import '../services/firebase_storage_upload_exception.dart';
import '../services/seller_payout_service.dart';
import '../utils/style.dart';
import '../utils/utils.dart';
import 'login.dart';
import 'new_product.dart';
import 'order_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  NotificationProvider? _notificationProvider;

  final List<Widget> _pages = const [
    _DashboardView(),
    OrdersPage(),
    ShippingPage(),
    AccountSection(),
  ];

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifications = context.read<NotificationProvider>();
    if (!identical(_notificationProvider, notifications)) {
      _notificationProvider?.removeListener(_handlePendingNotification);
      _notificationProvider = notifications;
      _notificationProvider?.addListener(_handlePendingNotification);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNotification();
    });
  }

  @override
  void dispose() {
    _notificationProvider?.removeListener(_handlePendingNotification);
    super.dispose();
  }

  void _handlePendingNotification() {
    if (!mounted || _notificationProvider == null) return;
    final pending = _notificationProvider!.pendingNavigation;
    if (pending == null) return;

    final orderProvider = context.read<OrderProvider>();
    final order = _findNotificationOrder(orderProvider, pending);
    final hasOrderTarget =
        pending.orderId.isNotEmpty || pending.orderDocumentId.isNotEmpty;
    if (hasOrderTarget && order == null && orderProvider.isLoading) {
      return;
    }

    final consumed = _notificationProvider!.consumePendingNavigation();
    if (consumed == null) return;
    final targetTab = consumed.targetTab ?? _resolveNotificationTab(consumed);
    if (targetTab != null && targetTab != _selectedIndex) {
      setState(() {
        _selectedIndex = targetTab;
      });
    }

    if (order != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showOrderDetailSheet(context, order);
      });
    }
  }

  SellerOrder? _findNotificationOrder(
    OrderProvider orderProvider,
    AppNotification notification,
  ) {
    if (notification.orderId.isNotEmpty) {
      final byId = orderProvider.findById(notification.orderId);
      if (byId != null) return byId;
    }
    if (notification.orderDocumentId.isNotEmpty) {
      for (final order in orderProvider.orders) {
        if (order.orderDocumentId == notification.orderDocumentId) {
          return order;
        }
      }
    }
    return null;
  }

  int? _resolveNotificationTab(AppNotification notification) {
    if (notification.targetTab != null) {
      return notification.targetTab;
    }
    final action = notification.action.toLowerCase();
    if (action.contains('shipping') || action.contains('delivery')) {
      return 2;
    }
    if (notification.orderId.isNotEmpty ||
        notification.orderDocumentId.isNotEmpty) {
      return 1;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: _SellerBottomBar(
        selectedIndex: _selectedIndex,
        onItemSelected: _selectTab,
        onPrimaryAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewProductScreen()),
          );
        },
      ),
    );
  }
}

class _SellerBottomBar extends StatelessWidget {
  const _SellerBottomBar({
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onPrimaryAction,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;
    final orderBadgeCount = orders
        .where(
          (order) =>
              order.status == OrderStatus.awaitingPayment ||
              order.status == OrderStatus.escrowFunded ||
              order.status == OrderStatus.preparingShipment ||
              order.status == OrderStatus.disputed,
        )
        .length;
    final shippingBadgeCount = orders
        .where(
          (order) =>
              order.status == OrderStatus.escrowFunded ||
              order.status == OrderStatus.preparingShipment ||
              order.status == OrderStatus.outForDelivery,
        )
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            active: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Order',
            active: selectedIndex == 1,
            badgeCount: orderBadgeCount,
            badgeColor: sellerRed,
            onTap: () => onItemSelected(1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPrimaryAction,
              child: Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: sellerRed,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          _NavItem(
            icon: Icons.local_shipping_outlined,
            label: 'Shipping',
            active: selectedIndex == 2,
            badgeCount: shippingBadgeCount,
            badgeColor: const Color(0xffE9A62B),
            onTap: () => onItemSelected(2),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Account',
            active: selectedIndex == 3,
            onTap: () => onItemSelected(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeColor = sellerRed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? sellerRed : Colors.grey.shade500;
    final displayBadge = badgeCount > 99 ? '99+' : '$badgeCount';
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color),
                if (badgeCount > 0)
                  Positioned(
                    right: -12,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        displayBadge,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final notifications = context.watch<NotificationProvider>();
    final products = context.watch<ProductProvider>();
    final salesRecords = orders.weeklySalesRecords;
    final sellerOrders = orders.orders;
    final awaitingPaymentCount = sellerOrders
        .where((order) => order.status == OrderStatus.awaitingPayment)
        .length;
    final readyToShipCount = sellerOrders
        .where(
          (order) =>
              order.status == OrderStatus.escrowFunded ||
              order.status == OrderStatus.preparingShipment,
        )
        .length;
    final awaitingReleaseCount = sellerOrders
        .where((order) => order.status == OrderStatus.delivered)
        .length;

    return RefreshIndicator(
      onRefresh: () => context.read<OrderProvider>().refreshOrders(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _DashboardHeader(
            unreadNotifications: notifications.unreadCount,
            onNotificationsTap: () =>
                context.read<NotificationProvider>().markAllAsRead(),
          ),
          if (context.watch<AuthProvider>().profileError != null) ...[
            const SizedBox(height: 16),
            _ProfileErrorBanner(
              message: context.watch<AuthProvider>().profileError!,
              onDismiss: () =>
                  context.read<AuthProvider>().clearProfileError(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'TZS ${formatCompact(orders.payoutsReady)}',
                  subtitle: 'Sales today',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: orders.activeOrders.toString(),
                  subtitle: 'Units today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EscrowFlowSnapshot(
            awaitingPaymentCount: awaitingPaymentCount,
            readyToShipCount: readyToShipCount,
            awaitingReleaseCount: awaitingReleaseCount,
          ),
          const SizedBox(height: 16),
          _SalesChartCard(records: salesRecords),
          const SizedBox(height: 16),
          _ActionList(
            onAddProduct: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewProductScreen()),
            ),
            onPaymentsTap: () => _showPaymentsFlowSheet(context),
            onReturnsTap: () => _showReturnsSheet(context),
            onCommunicationsTap: () => _showCommunicationsSheet(context),
          ),
          const SizedBox(height: 16),
          _ProductHighlightGrid(products: products.products),
        ],
      ),
    );
  }
}

/// Shown when the seller is signed in but their store could not be loaded.
/// Without this the account simply looks empty, which is indistinguishable
/// from having no products and no orders.
class _ProfileErrorBanner extends StatelessWidget {
  const _ProfileErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sellerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sellerRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: sellerRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your store did not load',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sellerRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.unreadNotifications,
    required this.onNotificationsTap,
  });

  final int unreadNotifications;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seller',
                style: TextStyle(
                  fontFamily: 'Fascinate-Regular',
                  fontSize: 24,
                  color: sellerGreen,
                ),
              ),
              // Text.rich(
              //   TextSpan(
              //     text: 'Kariakoonline',
              //     style: TextStyle(
              //       color: sellerGreen,
              //       fontWeight: FontWeight.w700,
              //       fontSize: 24,
              //       letterSpacing: 0.2,
              //     ),
              //     children: [
              //       TextSpan(
              //         text: ' Seller',
              //         style: TextStyle(
              //           fontFamily: 'Fascinate-Regular',
              //           color: sellerRed,
              //           fontSize: 24,
              //           fontWeight: FontWeight.w700,
              //           letterSpacing: 0.2,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotificationsTap,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (unreadNotifications > 0)
                Positioned(
                  right: 2,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: sellerRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _EscrowFlowSnapshot extends StatelessWidget {
  const _EscrowFlowSnapshot({
    required this.awaitingPaymentCount,
    required this.readyToShipCount,
    required this.awaitingReleaseCount,
  });

  final int awaitingPaymentCount;
  final int readyToShipCount;
  final int awaitingReleaseCount;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sellerGreen,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Escrow Flow',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            children: [
              Text(
                'Buyer has 15 minutes to pay. Once escrow is funded, the seller must pack, hand over, and confirm delivery before payout release.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FlowMetricChip(
                    value: awaitingPaymentCount,
                    label: 'waiting payment',
                  ),
                  _FlowMetricChip(
                    value: readyToShipCount,
                    label: 'seller action',
                  ),
                  _FlowMetricChip(
                    value: awaitingReleaseCount,
                    label: 'awaiting release',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowMetricChip extends StatelessWidget {
  const _FlowMetricChip({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({required this.records});

  final List<SalesRecord> records;

  @override
  Widget build(BuildContext context) {
    final maxRevenue = records.fold<double>(
      0,
      (max, record) => record.revenue > max ? record.revenue : max,
    );
    final totalRevenue = records.fold<double>(
      0,
      (sum, record) => sum + record.revenue,
    );
    final totalOrders = records.fold<int>(
      0,
      (sum, record) => sum + record.orders,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Sales chart',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Icon(Icons.trending_up, color: sellerGreen),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatCurrency(totalRevenue)} in $totalOrders orders this week',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          if (totalRevenue == 0)
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'No recorded sales for the last 7 days.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: records
                    .map(
                      (record) => Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              record.revenue > 0
                                  ? formatCompact(record.revenue)
                                  : '-',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: maxRevenue == 0
                                  ? 0
                                  : (record.revenue / maxRevenue).clamp(0, 1) *
                                      110,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xfffcd98d),
                                    Color(0xffffb347),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: records
                .map(
                  (record) => Text(
                    record.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({
    required this.onAddProduct,
    required this.onPaymentsTap,
    required this.onReturnsTap,
    required this.onCommunicationsTap,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onPaymentsTap;
  final VoidCallback onReturnsTap;
  final VoidCallback onCommunicationsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _ActionTile(
            title: 'Add product',
            subtitle: 'Create new listing in seconds',
            icon: Icons.add_box_outlined,
            onTap: onAddProduct,
          ),
          _ActionTile(
            title: 'Manage returns',
            subtitle: 'Review disputes, cancellations, and return-risk orders',
            icon: Icons.autorenew_outlined,
            onTap: onReturnsTap,
          ),
          _ActionTile(
            title: 'Payments',
            subtitle: '15-min payment window, escrow, payout release',
            icon: Icons.payments_outlined,
            onTap: onPaymentsTap,
          ),
          _ActionTile(
            title: 'Communications',
            subtitle: 'Unread alerts, payment reminders, and delivery updates',
            icon: Icons.message_outlined,
            onTap: onCommunicationsTap,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

void _showPaymentsFlowSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PaymentsFlowSheet(),
  );
}

void _showReturnsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ReturnsCenterSheet(),
  );
}

void _showCommunicationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CommunicationsSheet(),
  );
}

class _ReturnsCenterSheet extends StatelessWidget {
  const _ReturnsCenterSheet();

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final allOrders = orderProvider.orders;
    final reviewQueue = allOrders
        .where(
          (order) =>
              order.status == OrderStatus.disputed ||
              order.status == OrderStatus.cancelled ||
              order.status == OrderStatus.delivered,
        )
        .toList();
    final disputedOrders = reviewQueue
        .where((order) => order.status == OrderStatus.disputed)
        .toList();
    final cancelledOrders = reviewQueue
        .where((order) => order.status == OrderStatus.cancelled)
        .toList();
    final deliveredOrders = reviewQueue
        .where((order) => order.status == OrderStatus.delivered)
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: controller,
            children: [
              _SheetHeader(
                title: 'Returns Center',
                subtitle:
                    'Review orders that may need refund, return, or manual follow-up.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ReturnsMetricCard(
                    label: 'Disputes',
                    value: disputedOrders.length.toString(),
                    color: sellerRed,
                    icon: Icons.report_problem_outlined,
                  ),
                  _ReturnsMetricCard(
                    label: 'Cancelled',
                    value: cancelledOrders.length.toString(),
                    color: Colors.orange,
                    icon: Icons.cancel_outlined,
                  ),
                  _ReturnsMetricCard(
                    label: 'Delivered',
                    value: deliveredOrders.length.toString(),
                    color: Colors.indigo,
                    icon: Icons.inventory_2_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SellerInfoBanner(
                icon: Icons.assignment_return_outlined,
                color: sellerGreen,
                text:
                    'Use this queue to check delivered orders, track disputes, and respond fast when a buyer requests return or refund evidence.',
              ),
              const SizedBox(height: 18),
              if (reviewQueue.isEmpty)
                _EmptyStateCard(
                  text:
                      'No return or dispute cases need seller review right now.',
                )
              else
                ...reviewQueue.map(
                  (order) => _ReturnsOrderCard(order: order),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunicationsSheet extends StatelessWidget {
  const _CommunicationsSheet();

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final unread = notifications.unreadCount;
    final awaitingPayment = orderProvider.orders
        .where((order) => order.status == OrderStatus.awaitingPayment)
        .length;
    final shipping = orderProvider.orders
        .where(
          (order) =>
              order.status == OrderStatus.escrowFunded ||
              order.status == OrderStatus.preparingShipment ||
              order.status == OrderStatus.outForDelivery,
        )
        .length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: controller,
            children: [
              _SheetHeader(
                title: 'Communications',
                subtitle:
                    'Stay on top of seller alerts and use quick templates for common buyer updates.',
                trailing: TextButton(
                  onPressed: notifications.markAllAsRead,
                  child: const Text('Mark all read'),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ReturnsMetricCard(
                    label: 'Unread alerts',
                    value: unread.toString(),
                    color: sellerGreen,
                    icon: Icons.notifications_active_outlined,
                  ),
                  _ReturnsMetricCard(
                    label: 'Awaiting payment',
                    value: awaitingPayment.toString(),
                    color: Colors.orange,
                    icon: Icons.schedule_outlined,
                  ),
                  _ReturnsMetricCard(
                    label: 'Shipping updates',
                    value: shipping.toString(),
                    color: Colors.blueGrey,
                    icon: Icons.local_shipping_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Quick templates',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              const _MessageTemplateCard(
                title: 'Payment reminder',
                body:
                    'Hello, your Kariakoo order is waiting for payment. Please complete payment within 15 minutes so we can prepare your order.',
              ),
              const _MessageTemplateCard(
                title: 'Delivery update',
                body:
                    'Hello, your order has been packed and handed over for delivery. We will update you again when delivery is completed.',
              ),
              const _MessageTemplateCard(
                title: 'Issue follow-up',
                body:
                    'Hello, we are reviewing your order issue. Please keep your payment and delivery proof available while support checks the case.',
              ),
              const SizedBox(height: 18),
              const Text(
                'Recent alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (notifications.notifications.isEmpty)
                _EmptyStateCard(
                  text: 'No seller alerts yet.',
                )
              else
                ...notifications.notifications.take(8).map(
                      (notification) =>
                          _NotificationInboxCard(notification: notification),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
        if (trailing == null)
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}

class _SellerInfoBanner extends StatelessWidget {
  const _SellerInfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnsMetricCard extends StatelessWidget {
  const _ReturnsMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReturnsOrderCard extends StatelessWidget {
  const _ReturnsOrderCard({required this.order});

  final SellerOrder order;

  Future<void> _handleAction(
    BuildContext context, {
    required String title,
    required String hint,
    required Future<bool> Function(String note) onSubmit,
    required String successMessage,
  }) async {
    final note = await _showReturnActionSheet(
      context,
      title: title,
      hint: hint,
    );
    if (note == null || note.trim().isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await onSubmit(note.trim());
    if (!context.mounted) return;
    if (success) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Action failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      OrderStatus.disputed => sellerRed,
      OrderStatus.cancelled => Colors.orange,
      OrderStatus.delivered => Colors.indigo,
      _ => Colors.grey,
    };
    final statusText = switch (order.status) {
      OrderStatus.disputed => 'Dispute / return review',
      OrderStatus.cancelled => 'Cancelled order',
      OrderStatus.delivered => 'Delivered - monitor return risk',
      _ => orderStatusLabel(order.status),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.product.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _BadgeChip(
                label: statusText,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.orderNumber} • ${order.buyer.name}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Text(
            order.status == OrderStatus.disputed
                ? 'Check payment proof, delivery proof, and buyer complaint details before approving any refund.'
                : order.status == OrderStatus.cancelled
                    ? 'Confirm no handoff was made and keep evidence if payment had already been claimed.'
                    : 'Keep delivery proof available until the buyer confirms or the marketplace clears the return window.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (order.status == OrderStatus.delivered)
                _ReturnActionButton(
                  label: 'Start review',
                  icon: Icons.assignment_return_outlined,
                  filled: true,
                  onTap: () => _handleAction(
                    context,
                    title: 'Start Return Review',
                    hint:
                        'Add the reason or evidence that requires return/review.',
                    onSubmit: (note) => context
                        .read<OrderProvider>()
                        .openDispute(order.id, note),
                    successMessage: 'Return review started.',
                  ),
                ),
              if (order.status == OrderStatus.disputed)
                _ReturnActionButton(
                  label: 'Approve refund',
                  icon: Icons.check_circle_outline,
                  filled: true,
                  onTap: () => _handleAction(
                    context,
                    title: 'Approve Refund',
                    hint: 'Add refund note or evidence for the payout team.',
                    onSubmit: (note) => context
                        .read<OrderProvider>()
                        .approveRefund(order.id, note),
                    successMessage: 'Refund approval saved.',
                  ),
                ),
              if (order.status == OrderStatus.disputed)
                _ReturnActionButton(
                  label: 'Reject return',
                  icon: Icons.close_rounded,
                  onTap: () => _handleAction(
                    context,
                    title: 'Reject Return',
                    hint:
                        'Explain why the return is rejected and what evidence supports it.',
                    onSubmit: (note) => context
                        .read<OrderProvider>()
                        .rejectReturn(order.id, note),
                    successMessage: 'Return rejection saved.',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReturnActionButton extends StatelessWidget {
  const _ReturnActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: sellerRed,
            foregroundColor: Colors.white,
          )
        : OutlinedButton.styleFrom(
            foregroundColor: sellerRed,
          );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );

    return filled
        ? ElevatedButton(onPressed: onTap, style: style, child: child)
        : OutlinedButton(onPressed: onTap, style: style, child: child);
  }
}

Future<String?> _showReturnActionSheet(
  BuildContext context, {
  required String title,
  required String hint,
}) {
  final controller = TextEditingController();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sellerRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _MessageTemplateCard extends StatelessWidget {
  const _MessageTemplateCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: body));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$title copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
          Text(
            body,
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _NotificationInboxCard extends StatelessWidget {
  const _NotificationInboxCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final notifications = context.read<NotificationProvider>();
    final color = switch (notification.type) {
      NotificationType.payment => sellerGreen,
      NotificationType.order => sellerRed,
      NotificationType.review => Colors.indigo,
      NotificationType.report => Colors.orange,
      NotificationType.system => Colors.blueGrey,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => notifications.openNotification(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              notification.read ? Colors.white : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notification.read
                ? Colors.grey.shade200
                : color.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  formatDateTime(notification.createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notification.message,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade700),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PaymentsFlowSheet extends StatefulWidget {
  const _PaymentsFlowSheet();

  @override
  State<_PaymentsFlowSheet> createState() => _PaymentsFlowSheetState();
}

class _PaymentsFlowSheetState extends State<_PaymentsFlowSheet> {
  late final Stream<List<SellerPayout>> _payouts;

  @override
  void initState() {
    super.initState();
    _payouts = SellerPayoutService(
      sessionService: FirebaseSessionService(),
    ).watchPayouts();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ListView(
          controller: controller,
          children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Escrow releases and payouts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Seller payments follow the marketplace order flow. Do not ship unpaid orders.',
            style: TextStyle(height: 1.35),
          ),
          const SizedBox(height: 18),
          StreamBuilder<List<SellerPayout>>(
            stream: _payouts,
            builder: (context, snapshot) => _SettlementsSection(
              payouts: snapshot.data ?? const <SellerPayout>[],
              isLoading:
                  snapshot.connectionState == ConnectionState.waiting,
              hasError: snapshot.hasError,
            ),
          ),
          const SizedBox(height: 18),
          const _FlowStep(
            icon: Icons.schedule_outlined,
            title: '1. Buyer payment window',
            description:
                'The buyer has 15 minutes after placing the order to complete payment using the selected payment method.',
          ),
          const _FlowStep(
            icon: Icons.account_balance_wallet_outlined,
            title: '2. Funds held in escrow',
            description:
                'After payment is confirmed, the order becomes seller action. Funds stay protected until delivery progress is confirmed.',
          ),
          const _FlowStep(
            icon: Icons.local_shipping_outlined,
            title: '3. Seller delivery responsibility',
            description:
                'The seller must pack the order, hand it to pickup/delivery, and mark delivery steps truthfully in the seller app.',
          ),
          const _FlowStep(
            icon: Icons.payments_outlined,
            title: '4. Payout release',
            description:
                'Payout is ready only after delivery is confirmed or the marketplace releases escrow.',
          ),
          ],
        ),
      ),
    );
  }
}

/// Live view of the marketplace settlement ledger for this seller.
class _SettlementsSection extends StatelessWidget {
  const _SettlementsSection({
    required this.payouts,
    required this.isLoading,
    required this.hasError,
  });

  final List<SellerPayout> payouts;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final pending = payouts.where((payout) => !payout.isSettled);
    final pendingTotal =
        pending.fold<double>(0, (sum, payout) => sum + payout.netAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your settlements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          pending.isEmpty
              ? 'Released orders show up here with what the marketplace owes you.'
              : 'TZS ${formatCompact(pendingTotal)} on the way from '
                  '${pending.length} released order'
                  '${pending.length == 1 ? '' : 's'}.',
          style: TextStyle(color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 12),
        if (isLoading && payouts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasError)
          Text(
            'Could not load your settlements. Pull down to retry.',
            style: TextStyle(color: Colors.red.shade700),
          )
        else if (payouts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No payouts yet. Escrow is released once the buyer confirms '
              'delivery or the release window passes.',
              style: TextStyle(height: 1.35),
            ),
          )
        else
          ...payouts.map((payout) => _SettlementTile(payout: payout)),
      ],
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.payout});

  final SellerPayout payout;

  @override
  Widget build(BuildContext context) {
    final settled = payout.isSettled;
    final needsAccount =
        payout.status == SellerPayoutStatus.missingPayoutMethod;
    final accent = settled
        ? sellerGreen
        : needsAccount
            ? sellerRed
            : Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order ${payout.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${payout.currency} ${formatCompact(payout.netAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            payout.commissionAmount > 0
                ? 'Sale ${payout.currency} ${formatCompact(payout.grossAmount)} '
                    '· marketplace fee ${formatCompact(payout.commissionAmount)}'
                : 'Sale ${payout.currency} ${formatCompact(payout.grossAmount)} '
                    '· no marketplace fee',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          if (payout.destinationLabel.isNotEmpty)
            Text(
              'To ${payout.destinationLabel}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          if (needsAccount)
            Text(
              'Add a payout account so the marketplace can send this.',
              style: TextStyle(color: sellerRed, fontSize: 13),
            ),
          if (settled && payout.settlementReference.isNotEmpty)
            Text(
              'Reference ${payout.settlementReference}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              payout.status.label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: sellerGreen.withValues(alpha: 0.1),
            child: Icon(icon, color: sellerGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.showDivider = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: sellerGreen),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}

class _ProductHighlightGrid extends StatelessWidget {
  const _ProductHighlightGrid({required this.products});

  final List<ProductItem> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Listings snapshot',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final product = products[index];
              final cover = product.media.isNotEmpty
                  ? product.media.first
                  : 'https://via.placeholder.com/300';
              return GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ProductPreviewSheet(product: product),
                ),
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            child: SellerProductImage(
                              source: cover,
                              height: 130,
                              width: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _productStatusColor(product.status)
                                    .withOpacity(0.9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _productStatusLabel(product.status),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _productPriceHeadline(product),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sellerGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _productModeSummary(product),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

Color _productStatusColor(ProductStatus status) {
  switch (status) {
    case ProductStatus.pending:
      return Colors.orange;
    case ProductStatus.published:
      return sellerGreen;
    case ProductStatus.archived:
      return Colors.grey;
    case ProductStatus.draft:
      return Colors.blueGrey;
  }
}

String _productStatusLabel(ProductStatus status) {
  switch (status) {
    case ProductStatus.pending:
      return 'Under review';
    case ProductStatus.published:
      return 'Live';
    case ProductStatus.archived:
      return 'Paused';
    case ProductStatus.draft:
      return 'Draft';
  }
}

String _productPriceHeadline(ProductItem product) {
  if (product.availableForRetail &&
      product.availableForWholesale &&
      product.retailPrice > 0 &&
      product.wholesalePrice > 0) {
    return '${formatCurrency(product.retailPrice)} / ${formatCurrency(product.wholesalePrice)}';
  }
  return formatCurrency(product.displayPrice);
}

String _productPriceRangeLabel(ProductItem product) {
  if (product.availableForRetail &&
      product.availableForWholesale &&
      product.lowestPrice > 0 &&
      product.highestPrice > 0 &&
      product.lowestPrice != product.highestPrice) {
    return 'From ${formatCurrency(product.lowestPrice)} to ${formatCurrency(product.highestPrice)}';
  }
  return 'From ${formatCurrency(product.displayPrice)}';
}

String _productModeSummary(ProductItem product) {
  if (product.availableForRetail && product.availableForWholesale) {
    return 'Retail + Wholesale • Min wholesale ${product.wholesaleMinQty}';
  }
  if (product.availableForWholesale) {
    return 'Wholesale only • Min ${product.wholesaleMinQty} units';
  }
  return 'Retail only';
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OrderProvider>();
    final sellerProfile = context.read<AuthProvider>().profile;
    final primaryActionLabel = switch (order.status) {
      OrderStatus.escrowFunded => 'Mark packed',
      OrderStatus.preparingShipment => 'Mark in transit',
      OrderStatus.outForDelivery => 'Mark delivered',
      OrderStatus.delivered => 'Awaiting release',
      OrderStatus.awaitingPayment => 'Waiting for buyer',
      _ => 'No action',
    };
    Future<void> runAndClose(Future<bool> Function() action) async {
      final ok = await action();
      if (!context.mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.lastError ?? 'Could not update this order right now.',
          ),
        ),
      );
    }

    final primaryAction = switch (order.status) {
      OrderStatus.escrowFunded => () =>
          runAndClose(() => provider.markPacked(order.id)),
      OrderStatus.preparingShipment => () =>
          runAndClose(() => provider.markInTransit(order.id)),
      OrderStatus.outForDelivery => () =>
          runAndClose(() => provider.markDelivered(order.id)),
      _ => null,
    };
    final steps = [
      OrderStatus.awaitingPayment,
      OrderStatus.escrowFunded,
      OrderStatus.preparingShipment,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID: ${order.orderNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _statusText(order.status),
                        style: TextStyle(
                          color: _statusColor(order.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final status = entry.value;
                  final reached = _hasReachedOrderStep(order.status, status);
                  return Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  reached ? sellerRed : Colors.grey.shade300,
                              child: const Icon(Icons.check,
                                  size: 14, color: Colors.white),
                            ),
                            if (index != steps.length - 1)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: reached
                                      ? sellerRed
                                      : Colors.grey.shade300,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusText(status),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _OrderPaymentFlowNotice(order: order),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Customer details',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'Shipping Address',
                      value: order.shippingAddress,
                    ),
                    _InfoRow(
                      label: 'Buyer',
                      value: order.buyer.name,
                    ),
                    _InfoRow(
                      label: 'Shipping option',
                      value: order.deliveryMethod.isNotEmpty
                          ? order.deliveryMethod
                          : 'Not specified',
                      highlight: true,
                    ),
                    if (order.trackNumber.isNotEmpty)
                      _InfoRow(
                        label: 'Tracking number',
                        value: order.trackNumber,
                      ),
                    if (order.invoiceNumber.isNotEmpty)
                      _InfoRow(
                        label: 'Invoice number',
                        value: order.invoiceNumber,
                      ),
                    _InfoRow(
                      label: 'Payment',
                      value: order.isPaid ? 'Paid' : 'Awaiting payment',
                      highlight: true,
                    ),
                    if (order.isAwaitingBuyerPayment)
                      _InfoRow(
                        label: 'Payment window',
                        value:
                            '${_paymentWindowText(order)} - deadline ${formatDateTime(order.paymentDeadline)}',
                        highlight: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (sellerProfile != null && order.buyer.userId.trim().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SellerOrderChatScreen(
                            order: order,
                            seller: sellerProfile,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message_outlined),
                    label: const Text('Message buyer'),
                  ),
                ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Order detail',
                content: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SellerProductImage(
                          source: order.product.image,
                          width: 56,
                          height: 56,
                        ),
                      ),
                      title: Text(order.product.title),
                      subtitle: Text(
                        'Unit: ${order.quantity}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Text(formatCurrency(order.product.price)),
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Unit price',
                      value: formatCurrency(order.product.price),
                    ),
                    _SummaryRow(
                      label: 'Quantity',
                      value: '${order.quantity}',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Order Total',
                      value: formatCurrency(order.total),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Evidence',
                content: Column(
                  children: [
                    _ProofInfoTile(proof: order.paymentProof),
                    const Divider(),
                    _ProofInfoTile(proof: order.deliveryProof),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: primaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sellerRed,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(primaryActionLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return Colors.orange;
      case OrderStatus.escrowFunded:
      case OrderStatus.preparingShipment:
        return sellerGreen;
      case OrderStatus.outForDelivery:
        return Colors.blueGrey;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return 'Waiting payment';
      case OrderStatus.escrowFunded:
        return 'Escrow funded';
      case OrderStatus.preparingShipment:
        return 'Preparing shipment';
      case OrderStatus.outForDelivery:
        return 'In transit';
      case OrderStatus.delivered:
        return 'Awaiting release';
      case OrderStatus.completed:
        return 'Payout released';
      default:
        return status.name;
    }
  }
}

String _paymentWindowText(SellerOrder order) {
  final remaining = order.paymentTimeRemaining(DateTime.now());
  if (remaining.inSeconds <= 0) {
    return 'Payment window expired';
  }

  var minutes = (remaining.inSeconds / 60).ceil();
  if (minutes < 1) minutes = 1;
  if (minutes > SellerOrder.buyerPaymentWindow.inMinutes) {
    minutes = SellerOrder.buyerPaymentWindow.inMinutes;
  }
  return '$minutes min left to pay';
}

class _OrderPaymentFlowNotice extends StatelessWidget {
  const _OrderPaymentFlowNotice({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final expired = order.isPaymentWindowExpired(DateTime.now());
    final title = switch (order.status) {
      OrderStatus.awaitingPayment =>
        expired ? 'Payment window expired' : 'Waiting for buyer payment',
      OrderStatus.escrowFunded => 'Escrow funded - seller action pending',
      OrderStatus.preparingShipment => 'Escrow funded - prepare delivery',
      OrderStatus.outForDelivery => 'Delivery in progress',
      OrderStatus.delivered => 'Delivered - awaiting escrow release',
      OrderStatus.completed => 'Payout released',
      OrderStatus.disputed => 'Dispute in review',
      OrderStatus.cancelled => 'Order cancelled',
    };
    final description = switch (order.status) {
      OrderStatus.awaitingPayment => expired
          ? 'The buyer did not complete payment within 15 minutes. Do not pack or dispatch this order unless the marketplace confirms payment.'
          : 'The buyer has 15 minutes from order creation to pay. Seller should wait until funds are confirmed in escrow before packing or delivery handoff.',
      OrderStatus.escrowFunded =>
        'Payment is confirmed and funds are held in escrow. Seller should start packing and prepare the handoff.',
      OrderStatus.preparingShipment =>
        'Payment is held in escrow. Seller is responsible to pack the exact order and hand it to pickup or delivery.',
      OrderStatus.outForDelivery =>
        'Keep facilitating delivery and update the order only when the package is genuinely handed over or delivered.',
      OrderStatus.delivered =>
        'Delivery is marked complete. Payout remains held until buyer confirmation or marketplace escrow release.',
      OrderStatus.completed =>
        'Escrow has been released to the seller payout channel.',
      OrderStatus.disputed =>
        'Provide delivery and payment evidence while marketplace support reviews this order.',
      OrderStatus.cancelled =>
        'No seller fulfilment is required for this order.',
    };
    final color = switch (order.status) {
      OrderStatus.awaitingPayment => expired ? sellerRed : Colors.orange,
      OrderStatus.escrowFunded => sellerGreen,
      OrderStatus.preparingShipment => sellerGreen,
      OrderStatus.outForDelivery => Colors.blueGrey,
      OrderStatus.delivered => Colors.indigo,
      OrderStatus.completed => sellerGreen,
      OrderStatus.disputed => sellerRed,
      _ => Colors.grey,
    };
    final icon = switch (order.status) {
      OrderStatus.awaitingPayment => Icons.schedule_outlined,
      OrderStatus.escrowFunded => Icons.payments_outlined,
      OrderStatus.preparingShipment => Icons.inventory_2_outlined,
      OrderStatus.outForDelivery => Icons.local_shipping_outlined,
      OrderStatus.delivered => Icons.verified_outlined,
      OrderStatus.completed => Icons.payments_outlined,
      OrderStatus.disputed => Icons.report_problem_outlined,
      _ => Icons.info_outline,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    height: 1.35,
                  ),
                ),
                if (order.isAwaitingBuyerPayment) ...[
                  const SizedBox(height: 8),
                  Text(
                    _paymentWindowText(order),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.content});

  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? sellerRed : sellerBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _tabIndex = 0;

  List<SellerOrder> _filterOrders(List<SellerOrder> orders) {
    switch (_tabIndex) {
      case 1:
        return orders
            .where((o) => o.status == OrderStatus.awaitingPayment)
            .toList();
      case 2:
        return orders
            .where((o) =>
                o.status == OrderStatus.escrowFunded ||
                o.status == OrderStatus.preparingShipment ||
                o.status == OrderStatus.outForDelivery)
            .toList();
      case 3:
        return orders
            .where((o) =>
                o.status == OrderStatus.completed ||
                o.status == OrderStatus.delivered)
            .toList();
      default:
        return orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.orders;
    final filtered = _filterOrders(orders);
    final tabs = ['All orders', 'Pending', 'Shipping', 'Completed'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Orders'),
        const SizedBox(height: 12),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: List.generate(
              tabs.length,
              (index) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => setState(() => _tabIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _tabIndex == index
                          ? sellerRed.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                            color: _tabIndex == index
                                ? sellerRed
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: koScreenWidth(12, context)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (provider.lastError != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              provider.lastError!,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'No orders found for this seller yet.',
              textAlign: TextAlign.center,
            ),
          ),
        ...filtered.map(
          (order) => _OrderCard(
            order: order,
            onTap: () => _showOrderDetailSheet(context, order),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final SellerOrder order;
  final VoidCallback onTap;

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return Colors.orange;
      case OrderStatus.escrowFunded:
        return sellerGreen;
      case OrderStatus.preparingShipment:
      case OrderStatus.outForDelivery:
        return Colors.blueGrey;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.indigo;
      case OrderStatus.disputed:
        return sellerRed;
      default:
        return Colors.grey;
    }
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return 'Waiting payment';
      case OrderStatus.escrowFunded:
        return 'Escrow funded';
      case OrderStatus.preparingShipment:
        return 'Preparing shipment';
      case OrderStatus.outForDelivery:
        return 'Shipping';
      case OrderStatus.delivered:
        return 'Awaiting release';
      case OrderStatus.completed:
        return 'Payout released';
      case OrderStatus.disputed:
        return 'Dispute';
      default:
        return status.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SellerProductImage(
                source: order.product.image,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.product.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(order.total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: koScreenWidth(14, context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.orderNumber,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: koScreenWidth(12, context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _BadgeChip(
                        label: _statusText(order.status),
                        color: _statusColor(order.status),
                      ),
                      if (order.isAwaitingBuyerPayment)
                        _BadgeChip(
                          label: _paymentWindowText(order),
                          color: order.isPaymentWindowExpired(DateTime.now())
                              ? sellerRed
                              : Colors.orange,
                          light: true,
                        ),
                      _BadgeChip(
                        label: order.buyer.name,
                        color: Colors.blueGrey,
                        light: true,
                      ),
                      if (order.hasUnreadUpdates)
                        _BadgeChip(
                          label: 'New update',
                          color: sellerRed,
                          light: true,
                        ),
                      if (order.trackNumber.isNotEmpty)
                        _BadgeChip(
                          label: order.trackNumber,
                          color: Colors.blue,
                          light: true,
                        )
                      else if (order.deliveryMethod.isNotEmpty)
                        _BadgeChip(
                          label: order.deliveryMethod,
                          color: Colors.blue,
                          light: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.color,
    this.light = false,
  });

  final String label;
  final Color color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: light ? color.withOpacity(0.12) : color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: light ? color : color.darken(0.1),
          fontSize: koScreenWidth(10, context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ShippingPage extends StatelessWidget {
  const ShippingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.orders;
    final shippingOrders = orders
        .where((order) =>
            order.status == OrderStatus.escrowFunded ||
            order.status == OrderStatus.preparingShipment ||
            order.status == OrderStatus.outForDelivery ||
            order.status == OrderStatus.delivered)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Delivery & Shipping'),
        const SizedBox(height: 12),
        const _ShippingResponsibilityBanner(),
        const SizedBox(height: 12),
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ...shippingOrders.map(
          (order) => _ShippingCard(order: order),
        ),
        if (!provider.isLoading && shippingOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('No packages in transit right now.'),
            ),
          ),
      ],
    );
  }
}

class _ShippingResponsibilityBanner extends StatelessWidget {
  const _ShippingResponsibilityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sellerGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sellerGreen.withValues(alpha: 0.16)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_shipping_outlined, color: sellerGreen),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only paid escrow orders should be fulfilled. Seller is responsible for packing, handoff, and truthful delivery updates.',
              style: TextStyle(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final label = switch (order.status) {
      OrderStatus.escrowFunded => 'Mark packed',
      OrderStatus.preparingShipment => 'Mark in transit',
      OrderStatus.outForDelivery => 'Mark delivered',
      _ => 'Delivered',
    };
    Future<void> run(Future<bool> Function() action) async {
      final ok = await action();
      if (ok || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<OrderProvider>().lastError ??
                'Could not update this order right now.',
          ),
        ),
      );
    }

    final action = switch (order.status) {
      OrderStatus.escrowFunded => () =>
          run(() => context.read<OrderProvider>().markPacked(order.id)),
      OrderStatus.preparingShipment => () =>
          run(() => context.read<OrderProvider>().markInTransit(order.id)),
      OrderStatus.outForDelivery => () =>
          run(() => context.read<OrderProvider>().markDelivered(order.id)),
      _ => null,
    };
    final steps = [
      OrderStatus.escrowFunded,
      OrderStatus.preparingShipment,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.product.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.buyer.name} - ${order.shippingAddress}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: steps
                  .map(
                    (status) => Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor:
                                _hasReachedOrderStep(order.status, status)
                                    ? sellerGreen
                                    : Colors.grey.shade300,
                            child: const SizedBox(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusLabel(status),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              order.status == OrderStatus.escrowFunded
                  ? 'Escrow is funded. Start preparing the package and mark collected only after courier or pickup handoff.'
                  : order.status == OrderStatus.preparingShipment
                      ? 'Escrow is funded. Pack the order and mark collected only after courier/pickup handoff.'
                      : order.status == OrderStatus.outForDelivery
                          ? 'Keep delivery moving and mark delivered only after the buyer receives the package.'
                          : 'Delivery is confirmed; payout release depends on buyer or marketplace confirmation.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: action,
              icon: Icon(
                order.status == OrderStatus.preparingShipment
                    ? Icons.inventory_2_outlined
                    : Icons.local_shipping_outlined,
              ),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.escrowFunded:
        return 'Escrow';
      case OrderStatus.preparingShipment:
        return 'Packing';
      case OrderStatus.outForDelivery:
        return 'In transit';
      case OrderStatus.delivered:
        return 'Delivered';
      default:
        return status.name;
    }
  }
}

class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final products = context.watch<ProductProvider>().products;
    final profile = auth.profile;
    final channels = profile?.paymentChannels ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AccountHeader(
          profile: profile,
          listingCount: products.length,
        ),
        const SizedBox(height: 16),
        _AccountActions(auth: auth, profile: profile),
        const SizedBox(height: 16),
        _PaymentMethods(channels: channels, auth: auth),
        const SizedBox(height: 24),
        _ListingManager(products: products),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.profile,
    required this.listingCount,
  });

  final SellerProfile? profile;
  final int listingCount;

  Future<void> _openAccountSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final auth = sheetContext.read<AuthProvider>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Switch seller account'),
                  subtitle: const Text(
                    'Go back to login and sign in with another seller account on this device.',
                  ),
                  onTap: () async {
                    await auth.logout();
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    Navigator.of(sheetContext).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: sellerRed),
                  title: const Text('Logout'),
                  onTap: () async {
                    await auth.logout();
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    Navigator.of(sheetContext).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onAvatarTap(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final seller = auth.profile;
    if (seller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller profile is not ready yet. Try again shortly.'),
        ),
      );
      return;
    }

    final source = await _pickImageSource(context);
    if (source == null || !context.mounted) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !context.mounted) return;

      final croppedFile = await _cropLogo(context, picked.path);
      final imageFile = File(croppedFile?.path ?? picked.path);

      if (!context.mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await auth.uploadProfileImage(imageFile);
      } finally {
        if (navigator.canPop()) {
          navigator.pop();
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller logo updated.')),
      );
    } on FirebaseSessionException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not open images on this device.',
          ),
        ),
      );
    } on FirebaseStorageUploadException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update seller logo. Try again.'),
        ),
      );
    }
  }

  Future<ImageSource?> _pickImageSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Update seller logo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1A0B7A5F),
                    child:
                        Icon(Icons.photo_library_outlined, color: sellerGreen),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1AFF6B6B),
                    child: Icon(Icons.photo_camera_outlined, color: sellerRed),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<CroppedFile?> _cropLogo(
      BuildContext context, String sourcePath) async {
    try {
      return await ImageCropper().cropImage(
        sourcePath: sourcePath,
        maxWidth: 1200,
        maxHeight: 1200,
        compressQuality: 90,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Logo',
            toolbarColor: sellerRed,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: sellerRed,
            hideBottomControls: false,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Crop Logo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Widget _buildAvatar(String initials) {
    final avatarUrl = profile?.avatarUrl.trim() ?? '';
    if (avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          placeholder: (_, __) => CircleAvatar(
            radius: 36,
            backgroundColor: sellerGreen.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: sellerGreen,
              ),
            ),
          ),
          errorWidget: (_, __, ___) => CircleAvatar(
            radius: 36,
            backgroundColor: sellerGreen.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: sellerGreen,
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 36,
      backgroundColor: sellerGreen.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: sellerGreen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = (profile?.displayName ?? 'Seller').isNotEmpty
        ? profile!.displayName.characters.first.toUpperCase()
        : 'S';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: () => _onAvatarTap(context),
                    child: _buildAvatar(initials),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile != null && profile!.storeName.isNotEmpty
                                ? profile!.storeName
                                : 'Kariakoo Seller',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openAccountSheet(context),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          splashRadius: 20,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          profile?.businessType ?? 'Marketplace Partner',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.verified_user_outlined,
                          label: profile?.sellerStatus == false
                              ? 'Inactive'
                              : 'Active seller',
                          highlight: profile?.sellerStatus != false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        if (profile?.phoneNumber.isNotEmpty == true)
                          _MetaChip(
                            icon: Icons.phone_outlined,
                            label: profile!.phoneNumber,
                          ),
                        if (profile?.email.isNotEmpty == true)
                          _MetaChip(
                            icon: Icons.mail_outline,
                            label: profile!.email,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatChip(
                          label: 'Listings',
                          value: '$listingCount',
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                          label: 'Followers',
                          value: _compactNumber(profile?.followerCount ?? 0),
                        ),
                        const SizedBox(width: 12),
                        const _StatChip(label: 'Rating', value: '4.8'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddChannelSheet extends StatefulWidget {
  const _AddChannelSheet();

  @override
  State<_AddChannelSheet> createState() => _AddChannelSheetState();
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({
    required this.auth,
    required this.profile,
  });

  final AuthProvider auth;
  final SellerProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _QuickActionChip(
          label: 'Contact',
          icon: Icons.mail_outline,
          active: true,
          onTap: () => _showContactSheet(context, profile),
        ),
        _QuickActionChip(
          label: 'Settings',
          icon: Icons.settings_outlined,
          onTap: () => _openSettings(context, auth, profile),
        ),
        _QuickActionChip(
          label: 'Profile',
          icon: Icons.edit_outlined,
          onTap: () => _showEditProfileSheet(context, auth, profile),
        ),
      ],
    );
  }

  void _showEditProfileSheet(
    BuildContext context,
    AuthProvider auth,
    SellerProfile? profile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(
        auth: auth,
        profile: profile,
      ),
    );
  }

  void _showContactSheet(BuildContext context, SellerProfile? profile) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ContactSheet(profile: profile),
    );
  }

  void _openSettings(
    BuildContext context,
    AuthProvider auth,
    SellerProfile? profile,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SettingsScreen(
          auth: auth,
          profile: profile,
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({
    required this.auth,
    required this.profile,
  });

  final AuthProvider auth;
  final SellerProfile? profile;

  void _openEditProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(
        auth: auth,
        profile: profile,
      ),
    );
  }

  void _openContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ContactSheet(profile: profile),
    );
  }

  void _openGeneralStatement(
    BuildContext context,
    NotificationProvider notifications,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _GeneralStatementSheet(
        profile: profile,
        unreadNotifications: notifications.unreadCount,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(kPrivacyPolicyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the privacy policy.')),
      );
    }
  }

  /// Required by App Store Review 5.1.1(v) and Google Play. The backend
  /// refuses while buyer money is still in escrow or a payout is owed, and
  /// says why, so the seller is never silently removed mid-trade.
  Future<void> _deleteAccount(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final service = AccountDeletionService(
      sessionService: FirebaseSessionService(),
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    AccountDeletionCheck check;
    try {
      check = await service.check();
    } on AccountDeletionException catch (error) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    navigator.pop();
    if (!context.mounted) return;

    if (!check.canDelete) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Account cannot be deleted yet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final blocker in check.blockers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('\u2022 $blocker'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete account'),
            content: const Text(
              'This permanently removes your seller account, your payout '
              'accounts and your access to this app. Your listings are '
              'withdrawn from the marketplace.\n\n'
              'Completed order records are kept for accounting and dispute '
              'purposes, as the law requires.\n\n'
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: sellerRed),
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await service.deleteAccount();
      await auth.logout();
      navigator.pop();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } on AccountDeletionException catch (error) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: sellerBlack, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: sellerBlack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: sellerGreen.withValues(alpha: 0.12),
                  child: Text(
                    (profile?.displayName.isNotEmpty == true
                            ? profile!.displayName.characters.first
                            : 'S')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: sellerGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.storeName.isNotEmpty == true
                            ? profile!.storeName
                            : 'Kariakoo Seller',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?.phoneNumber.isNotEmpty == true
                            ? profile!.phoneNumber
                            : 'Seller account',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  iconColor: const Color(0xffE9A62B),
                  title: 'Seller Account',
                  subtitle: 'Profile and business details',
                  onTap: () => _openEditProfileSheet(context),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xff6E8EFB),
                  title: 'General Statement',
                  subtitle: 'Store activity and setup overview',
                  onTap: () => _openGeneralStatement(context, notifications),
                ),
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xffF08A8A),
                  title: 'Notifications',
                  subtitle: notifications.unreadCount == 0
                      ? 'No unread alerts'
                      : '${notifications.unreadCount} unread alerts',
                  onTap: notifications.markAllAsRead,
                ),
                _SettingsTile(
                  icon: Icons.language_outlined,
                  iconColor: const Color(0xff6BC7B8),
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language settings will be added soon.'),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.help_outline,
                  iconColor: const Color(0xffF2B84B),
                  title: 'Seller Help Center',
                  subtitle: 'Support and contact channels',
                  onTap: () => _openContactSheet(context),
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  iconColor: const Color(0xff84A4FF),
                  title: 'About',
                  subtitle: 'Kariakoo Online Seller App',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Kariakoo Seller',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          'Seller operations app for Kariakoo Online Marketplace.',
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: const Color(0xff84A4FF),
                  title: 'Privacy Policy',
                  subtitle: 'How Kariakoonline handles your data',
                  onTap: () => _openPrivacyPolicy(context),
                ),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  iconColor: sellerRed,
                  title: 'Log Out',
                  subtitle: 'Sign out from this device',
                  isDestructive: true,
                  onTap: () => _logout(context),
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  iconColor: sellerRed,
                  title: 'Delete Account',
                  subtitle: 'Permanently remove your store and your data',
                  isDestructive: true,
                  onTap: () => _deleteAccount(context),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDestructive ? sellerRed : sellerBlack,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.grey.shade500,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: Colors.grey.shade100,
          ),
      ],
    );
  }
}

class _GeneralStatementSheet extends StatelessWidget {
  const _GeneralStatementSheet({
    required this.profile,
    required this.unreadNotifications,
  });

  final SellerProfile? profile;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'General Statement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 14),
          _StatementRow(
            label: 'Store',
            value: profile?.storeName.isNotEmpty == true
                ? profile!.storeName
                : 'Kariakoo Seller',
          ),
          _StatementRow(
            label: 'Business type',
            value: profile?.businessType.isNotEmpty == true
                ? profile!.businessType
                : 'General',
          ),
          _StatementRow(
            label: 'Followers',
            value: '${profile?.followerCount ?? 0}',
          ),
          _StatementRow(
            label: 'Notifications',
            value: unreadNotifications == 0
                ? 'No unread alerts'
                : '$unreadNotifications unread alerts',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: sellerRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    this.active = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: active ? sellerRed : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : sellerRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? sellerGreen.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? sellerGreen : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? sellerGreen : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _compactNumber(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}m';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return '$value';
}

class _ContactSheet extends StatelessWidget {
  const _ContactSheet({required this.profile});

  final SellerProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seller Contact',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Phone'),
            subtitle: Text(profile?.phoneNumber.isNotEmpty == true
                ? profile!.phoneNumber
                : 'No phone available'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: const Text('Email'),
            subtitle: Text(profile?.email.isNotEmpty == true
                ? profile!.email
                : 'No email available'),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.auth,
    required this.profile,
  });

  final AuthProvider auth;
  final SellerProfile? profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _storeController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _storeController =
        TextEditingController(text: widget.profile?.storeName ?? '');
    _businessTypeController =
        TextEditingController(text: widget.profile?.businessType ?? '');
    _emailController = TextEditingController(text: widget.profile?.email ?? '');
    _bioController = TextEditingController(text: widget.profile?.bio ?? '');
  }

  @override
  void dispose() {
    _storeController.dispose();
    _businessTypeController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Edit Seller Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _storeController,
            decoration: const InputDecoration(labelText: 'Store name'),
          ),
          TextField(
            controller: _businessTypeController,
            decoration: const InputDecoration(labelText: 'Business type'),
          ),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(labelText: 'Bio'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: sellerRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await widget.auth.updateProfile(
      displayName: _storeController.text.trim(),
      storeName: _storeController.text.trim(),
      businessType: _businessTypeController.text.trim(),
      email: _emailController.text.trim(),
      bio: _bioController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods({required this.channels, required this.auth});

  final List<PaymentChannel> channels;
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Payment methods',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openAddChannel(context),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: channels.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () => _openAddChannel(context),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: sellerGreen.withOpacity(0.1),
                        child: const Icon(Icons.add, color: sellerGreen),
                      ),
                      const SizedBox(height: 6),
                      const Text('Add'),
                    ],
                  ),
                );
              }
              final channel = channels[index - 1];
              return GestureDetector(
                onTap: () => _showPaymentDetail(context, channel),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: channel.isPrimary
                              ? sellerGreen
                              : Colors.grey.shade300,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey.shade100,
                        radius: 30,
                        child: ClipOval(
                          child: Image.asset(
                            _paymentIcon(channel.type),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      channel.type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAddChannel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddChannelSheet(),
    );
  }

  void _showPaymentDetail(BuildContext context, PaymentChannel channel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentDetailSheet(channel: channel),
    );
  }
}

String _paymentIcon(PaymentChannelType type) {
  switch (type) {
    case PaymentChannelType.mpesa:
      return 'assets/icons/mpesa-icon.jpg';
    case PaymentChannelType.airtelMoney:
      return 'assets/icons/airtel-icon.jpg';
    case PaymentChannelType.tigopesa:
      return 'assets/icons/tigopesa-icon.jpg';
    default:
      return 'assets/icons/back-icon.jpg';
  }
}

class _ListingManager extends StatelessWidget {
  const _ListingManager({required this.products});

  final List<ProductItem> products;

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final filtered = products.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your listings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showListingFilterSheet(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: sellerBlack),
                      SizedBox(width: 6),
                      Text(
                        'Filter',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, index) {
            final product = filtered[index];
            final reservedUnits =
                orderProvider.reservedUnitsForProduct(product);
            final availableUnits =
                orderProvider.availableUnitsForProduct(product);
            final source = product.media.isNotEmpty
                ? product.media.first
                : 'https://via.placeholder.com/80';
            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _ProductPreviewSheet(product: product),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: SellerProductImage(
                        source: source,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _productPriceRangeLabel(product),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _productModeSummary(product),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Status: ${_productStatusLabel(product.status)}',
                            style: TextStyle(
                              color: _productStatusColor(product.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Stock ${product.stock} • Reserved $reservedUnits • Available $availableUnits',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

void _showListingFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ListingFilterSheet(),
  );
}

class _ListingFilterSheet extends StatelessWidget {
  const _ListingFilterSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filter listings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const _FilterOptionTile(
              icon: Icons.check_circle_outline,
              title: 'Published',
              subtitle: 'Show active seller listings',
            ),
            const _FilterOptionTile(
              icon: Icons.edit_note_outlined,
              title: 'Draft',
              subtitle: 'Show unfinished listings',
            ),
            const _FilterOptionTile(
              icon: Icons.pause_circle_outline,
              title: 'Paused',
              subtitle: 'Show archived or hidden listings',
            ),
            const _FilterOptionTile(
              icon: Icons.pending_actions_outlined,
              title: 'Under review',
              subtitle: 'Show listings waiting for review',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sellerRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: sellerGreen.withValues(alpha: 0.12),
        child: Icon(icon, size: 18, color: sellerGreen),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
    );
  }
}

class _PaymentDetailSheet extends StatelessWidget {
  const _PaymentDetailSheet({required this.channel});

  final PaymentChannel channel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Payment Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                _paymentIcon(channel.type),
                width: 64,
                height: 64,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            channel.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(channel.accountNumber),
          if (channel.instructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                channel.instructions,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sellerRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sellerRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: channel.isPrimary
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          try {
                            await context
                                .read<AuthProvider>()
                                .setPrimaryChannel(channel.id);
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${channel.displayName} is now your payout '
                                  'account.',
                                ),
                              ),
                            );
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not set the payout account: $error',
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    channel.isPrimary ? 'Primary account' : 'Make Primary',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddChannelSheetState extends State<_AddChannelSheet> {
  PaymentChannelType _type = PaymentChannelType.mpesa;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();
  bool _primary = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PaymentChannelType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Channel type'),
            items: PaymentChannelType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value!),
          ),
          TextField(
            controller: _nameController,
            enabled: !_isSaving,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          TextField(
            controller: _accountController,
            enabled: !_isSaving,
            decoration: const InputDecoration(labelText: 'Account / Number'),
          ),
          TextField(
            controller: _instructionController,
            enabled: !_isSaving,
            decoration: const InputDecoration(labelText: 'Instructions'),
          ),
          SwitchListTile(
            title: const Text('Set as primary payout channel'),
            value: _primary,
            onChanged:
                _isSaving ? null : (value) => setState(() => _primary = value),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: sellerRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _isSaving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final displayName = _nameController.text.trim();
                      final accountNumber = _accountController.text.trim();
                      final instructions = _instructionController.text.trim();

                      if (displayName.isEmpty || accountNumber.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Display name and account number are required.',
                            ),
                          ),
                        );
                        return;
                      }

                      setState(() => _isSaving = true);
                      final navigator = Navigator.of(context);
                      final channel = PaymentChannel(
                        id: const Uuid().v4(),
                        type: _type,
                        displayName: displayName,
                        accountNumber: accountNumber,
                        instructions: instructions,
                        isPrimary: _primary,
                      );

                      try {
                        await auth.addPaymentChannel(channel);
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Payment method saved.'),
                          ),
                        );
                      } on FirebaseSessionException catch (error) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      } catch (_) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to save payment method. Try again.',
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isSaving = false);
                        }
                      }
                    },
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Text('Save Payment Method'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPreviewSheet extends StatelessWidget {
  const _ProductPreviewSheet({required this.product});

  final ProductItem product;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProductProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final reservedUnits = orderProvider.reservedUnitsForProduct(product);
    final availableUnits = orderProvider.availableUnitsForProduct(product);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                product.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SellerProductImage(
                  source: product.media.isNotEmpty
                      ? product.media.first
                      : 'https://via.placeholder.com/500',
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(product.description.isEmpty
                  ? 'No description added yet.'
                  : product.description),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InsightChip(label: 'Stock', value: product.stock),
                  _InsightChip(label: 'Reserved', value: reservedUnits),
                  _InsightChip(label: 'Available', value: availableUnits),
                  _InsightChip(label: 'Views', value: product.metrics.views),
                  _InsightChip(label: 'Likes', value: product.metrics.likes),
                  _InsightChip(
                      label: 'Reviews', value: product.metrics.reviews),
                ],
              ),
              const SizedBox(height: 24),
              ..._buildStatusActions(context, provider),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await provider.removeProduct(product.id);
                    navigator.pop();
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not remove this listing. Try again.',
                        ),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: sellerRed),
                child: Text(
                  product.status == ProductStatus.published
                      ? 'Archive listing'
                      : 'Remove listing',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildStatusActions(
      BuildContext context, ProductProvider provider) {
    switch (product.status) {
      case ProductStatus.draft:
        return [
          ElevatedButton(
            onPressed: () async {
              await provider.setStatus(product.id, ProductStatus.pending);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Send for review'),
          ),
        ];
      case ProductStatus.pending:
        return [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'This listing is waiting for marketplace moderation. Only the marketplace team can approve and release it to buyers.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              await provider.setStatus(product.id, ProductStatus.draft);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Back to draft'),
          ),
        ];
      case ProductStatus.published:
        return [
          ElevatedButton(
            onPressed: () async {
              await provider.setStatus(product.id, ProductStatus.archived);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Pause listing'),
          ),
        ];
      case ProductStatus.archived:
        return [
          ElevatedButton(
            onPressed: () async {
              await provider.setStatus(product.id, ProductStatus.pending);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Resubmit for review'),
          ),
        ];
    }
  }
}

void _showOrderDetailSheet(BuildContext context, SellerOrder order) {
  context.read<OrderProvider>().markUpdatesAsRead(order.id);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OrderDetailSheet(order: order),
  );
}

bool _hasReachedOrderStep(OrderStatus current, OrderStatus step) {
  switch (step) {
    case OrderStatus.awaitingPayment:
      return true;
    case OrderStatus.escrowFunded:
      return current != OrderStatus.awaitingPayment &&
          current != OrderStatus.cancelled;
    case OrderStatus.preparingShipment:
      return current == OrderStatus.preparingShipment ||
          current == OrderStatus.outForDelivery ||
          current == OrderStatus.delivered ||
          current == OrderStatus.completed ||
          current == OrderStatus.disputed;
    case OrderStatus.outForDelivery:
      return current == OrderStatus.outForDelivery ||
          current == OrderStatus.delivered ||
          current == OrderStatus.completed ||
          current == OrderStatus.disputed;
    case OrderStatus.delivered:
      return current == OrderStatus.delivered ||
          current == OrderStatus.completed;
    case OrderStatus.completed:
      return current == OrderStatus.completed;
    case OrderStatus.disputed:
      return current == OrderStatus.disputed;
    case OrderStatus.cancelled:
      return current == OrderStatus.cancelled;
  }
}

class _ProofInfoTile extends StatelessWidget {
  const _ProofInfoTile({required this.proof});

  final OrderProof proof;

  @override
  Widget build(BuildContext context) {
    final color = switch (proof.status) {
      OrderProofStatus.verified => sellerGreen,
      OrderProofStatus.submitted => Colors.orange,
      OrderProofStatus.rejected => sellerRed,
      OrderProofStatus.missing => Colors.grey,
    };

    final details = [
      if (proof.reference.isNotEmpty) 'Ref: ${proof.reference}',
      if (proof.note.isNotEmpty) proof.note,
      if (proof.submittedAt != null)
        'Submitted ${formatDateTime(proof.submittedAt!)}',
      if (proof.verifiedAt != null)
        'Verified ${formatDateTime(proof.verifiedAt!)}',
    ].join(' • ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          proof.label == 'Payment proof'
              ? Icons.receipt_long_outlined
              : Icons.verified_user_outlined,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        proof.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        details.isEmpty ? 'No proof has been attached yet.' : details,
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Text(
        orderProofStatusLabel(proof.status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCompact(value),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class SellerProductImage extends StatelessWidget {
  const SellerProductImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: source,
        width: width,
        height: height,
        fit: fit,
      );
    }
    return Image.file(
      File(source),
      width: width,
      height: height,
      fit: fit,
    );
  }
}

extension ColorShade on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
