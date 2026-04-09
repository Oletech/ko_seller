import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../model/order_item.dart';
import '../model/payment_channel.dart';
import '../model/seller_profile.dart';
import '../model/product_item.dart';
import '../model/sales_record.dart';
import '../provider/auth_provider.dart';
import '../provider/notification_provider.dart';
import '../provider/order_provider.dart';
import '../provider/product_provider.dart';
import '../services/firebase_session_service.dart';
import '../services/firebase_storage_upload_exception.dart';
import '../utils/style.dart';
import '../utils/utils.dart';
import 'login.dart';
import 'new_product.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? sellerRed : Colors.grey.shade500;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
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
          _SalesChartCard(records: salesRecords),
          const SizedBox(height: 16),
          _ActionList(
            onAddProduct: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewProductScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _ProductHighlightGrid(products: products.products),
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
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              height: maxRevenue == 0
                                  ? 0
                                  : (record.revenue / maxRevenue)
                                          .clamp(0, 1) *
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
  const _ActionList({required this.onAddProduct});

  final VoidCallback onAddProduct;

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
            subtitle: 'Track and approve buyer returns',
            icon: Icons.autorenew_outlined,
            onTap: () {},
          ),
          _ActionTile(
            title: 'Payments',
            subtitle: 'Escrow releases and payouts',
            icon: Icons.payments_outlined,
            onTap: () {},
          ),
          _ActionTile(
            title: 'Communications',
            subtitle: 'Messages & campaigns',
            icon: Icons.message_outlined,
            onTap: () {},
            showDivider: false,
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
                              formatCurrency(product.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sellerGreen,
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
    default:
      return Colors.blueGrey;
  }
}

String _productStatusLabel(ProductStatus status) {
  switch (status) {
    case ProductStatus.pending:
      return 'Pending';
    case ProductStatus.published:
      return 'Live';
    case ProductStatus.archived:
      return 'Paused';
    case ProductStatus.draft:
    default:
      return 'Draft';
  }
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OrderProvider>();
    final primaryActionLabel = switch (order.status) {
      OrderStatus.preparingShipment => 'Mark collected',
      OrderStatus.outForDelivery => 'Mark delivered',
      OrderStatus.delivered => 'Delivered',
      _ => 'Awaiting payment',
    };
    final primaryAction = switch (order.status) {
      OrderStatus.preparingShipment => () async {
          await provider.markOrderCollected(order.id);
          if (context.mounted) Navigator.of(context).pop();
        },
      OrderStatus.outForDelivery => () async {
          await provider.submitProofOfDelivery(order.id);
          if (context.mounted) Navigator.of(context).pop();
        },
      _ => null,
    };
    final steps = [
      OrderStatus.awaitingPayment,
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
                  final reached = order.status.index >= status.index;
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
                  ],
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
      case OrderStatus.preparingShipment:
      case OrderStatus.outForDelivery:
        return Colors.blueGrey;
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return 'Pending';
      case OrderStatus.preparingShipment:
        return 'Accepted';
      case OrderStatus.outForDelivery:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      default:
        return status.name;
    }
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
            onTap: () => _showOrderDetail(context, order),
          ),
        ),
      ],
    );
  }

  void _showOrderDetail(BuildContext context, SellerOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OrderDetailSheet(order: order),
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
      case OrderStatus.preparingShipment:
      case OrderStatus.outForDelivery:
        return Colors.blueGrey;
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.disputed:
        return sellerRed;
      default:
        return Colors.grey;
    }
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return 'Pending';
      case OrderStatus.preparingShipment:
        return 'Packing';
      case OrderStatus.outForDelivery:
        return 'Shipping';
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return 'Completed';
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
                      _BadgeChip(
                        label: order.buyer.name,
                        color: Colors.blueGrey,
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
            order.status == OrderStatus.preparingShipment ||
            order.status == OrderStatus.outForDelivery ||
            order.status == OrderStatus.delivered)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Delivery & Shipping'),
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

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final label = switch (order.status) {
      OrderStatus.preparingShipment => 'Mark collected',
      OrderStatus.outForDelivery => 'Mark delivered',
      _ => 'Delivered',
    };
    final action = switch (order.status) {
      OrderStatus.preparingShipment => () =>
          context.read<OrderProvider>().markOrderCollected(order.id),
      OrderStatus.outForDelivery => () =>
          context.read<OrderProvider>().submitProofOfDelivery(order.id),
      _ => null,
    };
    final steps = [
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
            const SizedBox(height: 8),
            Row(
              children: steps
                  .map(
                    (status) => Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: order.status.index >= status.index
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
                    child: Icon(Icons.photo_library_outlined, color: sellerGreen),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1AFF6B6B),
                    child: Icon(Icons.photo_camera_outlined, color: sellerRed),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<CroppedFile?> _cropLogo(BuildContext context, String sourcePath) async {
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
                          icon:
                              const Icon(Icons.keyboard_arrow_down_rounded),
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
          label: 'Statistics',
          icon: Icons.bar_chart,
          onTap: () {},
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
    final filtered = products.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your listings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search listing by SKU',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          ),
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
                            'From ${formatCurrency(product.price)}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${_productStatusLabel(product.status)}',
                            style: TextStyle(
                              color: _productStatusColor(product.status),
                              fontWeight: FontWeight.w600,
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
                  onPressed: () {},
                  child: const Text('Make Primary'),
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
                onPressed: () {
                  provider.removeProduct(product.id);
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: sellerRed),
                child: const Text('Remove listing'),
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
          ElevatedButton(
            onPressed: () async {
              await provider.setStatus(product.id, ProductStatus.published);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Approve & publish'),
          ),
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
              await provider.setStatus(product.id, ProductStatus.pending);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Pause & review'),
          ),
        ];
      case ProductStatus.archived:
        return [
          ElevatedButton(
            onPressed: () async {
              await provider.setStatus(product.id, ProductStatus.pending);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Relist product'),
          ),
        ];
    }
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
