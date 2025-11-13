import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../model/order_item.dart';
import '../model/payment_channel.dart';
import '../model/product_item.dart';
import '../model/sales_record.dart';
import '../provider/auth_provider.dart';
import '../provider/notification_provider.dart';
import '../provider/order_provider.dart';
import '../provider/product_provider.dart';
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
    final salesRecords = SalesRecord.weeklySeed();

    return RefreshIndicator(
      onRefresh: () => context.read<OrderProvider>().simulateIncomingOrder(),
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
    final auth = context.read<AuthProvider>();
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {},
        ),
        const Expanded(
          child: Column(
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
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            auth.logout();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
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
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: records
                  .map(
                    (record) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: (record.revenue / 300000).clamp(0, 1) * 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xfffcd98d), Color(0xffffb347)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
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
                .map((e) => Text(
                      e.label,
                      style: const TextStyle(fontSize: 12),
                    ))
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

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
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
              const _InfoCard(
                title: 'Customer details',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'Shipping Address',
                      value: 'Kariakoo, Ilala - Dar es Salaam',
                    ),
                    _InfoRow(
                      label: 'Payment method',
                      value: 'Escrow wallet • **** 3947',
                    ),
                    _InfoRow(
                      label: 'Shipping option',
                      value: 'Pick up in store',
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
                      label: 'Items',
                      value: formatCurrency(order.product.price),
                    ),
                    _SummaryRow(
                      label: 'Delivery fee',
                      value: formatCurrency(5000),
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Order Total',
                      value: formatCurrency(order.total + 5000),
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
                      onPressed: () =>
                          Navigator.of(context).pop(), // placeholder
                      child: const Text('Cancel order'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(), // placeholder
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sellerRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Ready for pick up'),
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
    final orders = context.watch<OrderProvider>().orders;
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
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.orderNumber,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _BadgeChip(
                        label: _statusText(order.status),
                        color: _statusColor(order.status),
                      ),
                      const SizedBox(width: 6),
                      _BadgeChip(
                        label: order.buyer.name,
                        color: Colors.blueGrey,
                        light: true,
                      ),
                      const SizedBox(width: 6),
                      const _BadgeChip(
                        label: '60051 - NY',
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
          fontSize: 11,
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
    final orders = context.watch<OrderProvider>().orders;
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
        ...shippingOrders.map(
          (order) => _ShippingCard(order: order),
        ),
        if (shippingOrders.isEmpty)
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
              onPressed: () =>
                  context.read<OrderProvider>().submitProofOfDelivery(order.id),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload delivery proof'),
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

class AccountSection extends StatefulWidget {
  const AccountSection({super.key});

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  late TextEditingController _nameController;
  late TextEditingController _storeController;
  late TextEditingController _businessController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _storeController = TextEditingController(text: profile?.storeName ?? '');
    _businessController =
        TextEditingController(text: profile?.businessType ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeController.dispose();
    _businessController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final channels = profile?.paymentChannels ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Account'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: sellerGreen.withOpacity(0.1),
                child: Text(
                  (profile?.displayName ?? 'KS').isNotEmpty
                      ? profile!.displayName.characters.first.toUpperCase()
                      : 'K',
                  style: const TextStyle(
                    fontSize: 24,
                    color: sellerGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile?.displayName.isNotEmpty == true
                    ? profile!.displayName
                    : 'Kariakoo Seller',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(profile?.phoneNumber ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _editField('Display name', _nameController, auth),
        _editField('Store name', _storeController, auth),
        _editField('Business type', _businessController, auth),
        _editField('About store', _bioController, auth, minLines: 3),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Payment channels',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openAddChannel(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        ...channels.map(
          (channel) => Card(
            child: ListTile(
              leading: Icon(
                Icons.account_balance_wallet_outlined,
                color: channel.isPrimary ? sellerGreen : Colors.grey,
              ),
              title: Text('${channel.displayName} • ${channel.type.label}'),
              subtitle: Text(channel.accountNumber),
              trailing: channel.isPrimary
                  ? const Text('Primary', style: TextStyle(color: sellerGreen))
                  : TextButton(
                      onPressed: () => auth.setPrimaryChannel(channel.id),
                      child: const Text('Make primary'),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _editField(
      String label, TextEditingController controller, AuthProvider auth,
      {int minLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines == 1 ? 1 : 5,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onSubmitted: (_) => auth.updateProfile(
          displayName: _nameController.text,
          storeName: _storeController.text,
          businessType: _businessController.text,
          bio: _bioController.text,
        ),
      ),
    );
  }

  void _openAddChannel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddChannelSheet(),
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

class _AddChannelSheet extends StatefulWidget {
  const _AddChannelSheet();

  @override
  State<_AddChannelSheet> createState() => _AddChannelSheetState();
}

class _AddChannelSheetState extends State<_AddChannelSheet> {
  PaymentChannelType _type = PaymentChannelType.mpesa;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();
  bool _primary = false;

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
            value: _type,
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
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          TextField(
            controller: _accountController,
            decoration: const InputDecoration(labelText: 'Account / Number'),
          ),
          TextField(
            controller: _instructionController,
            decoration: const InputDecoration(labelText: 'Instructions'),
          ),
          SwitchListTile(
            title: const Text('Set as primary payout channel'),
            value: _primary,
            onChanged: (value) => setState(() => _primary = value),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final channel = PaymentChannel(
                id: const Uuid().v4(),
                type: _type,
                displayName: _nameController.text,
                accountNumber: _accountController.text,
                instructions: _instructionController.text,
                isPrimary: _primary,
              );
              await auth.addPaymentChannel(channel);
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Save channel'),
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
              ElevatedButton(
                onPressed: () => provider.togglePublish(product.id),
                child: Text(
                  product.status == ProductStatus.published
                      ? 'Move to draft'
                      : 'Publish listing',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  provider.removeProduct(product.id);
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: sellerRed,
                ),
                child: const Text('Remove product'),
              ),
            ],
          ),
        );
      },
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
