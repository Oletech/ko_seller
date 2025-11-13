import 'package:equatable/equatable.dart';

class SalesRecord extends Equatable {
  final String label;
  final double revenue;
  final double payoutReleased;
  final double payoutOnHold;
  final int orders;
  final int unitsSold;
  final double averageOrderValue;
  final List<double> trendPoints;

  const SalesRecord({
    required this.label,
    required this.revenue,
    required this.payoutReleased,
    required this.payoutOnHold,
    required this.orders,
    required this.unitsSold,
    required this.averageOrderValue,
    required this.trendPoints,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'revenue': revenue,
        'payoutReleased': payoutReleased,
        'payoutOnHold': payoutOnHold,
        'orders': orders,
        'unitsSold': unitsSold,
        'averageOrderValue': averageOrderValue,
        'trendPoints': trendPoints,
      };

  factory SalesRecord.fromJson(Map<String, dynamic> json) {
    return SalesRecord(
      label: json['label'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      payoutReleased: (json['payoutReleased'] as num?)?.toDouble() ?? 0,
      payoutOnHold: (json['payoutOnHold'] as num?)?.toDouble() ?? 0,
      orders: json['orders'] as int? ?? 0,
      unitsSold: json['unitsSold'] as int? ?? 0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0,
      trendPoints: (json['trendPoints'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  static List<SalesRecord> weeklySeed() {
    return const [
      SalesRecord(
        label: 'Mon',
        revenue: 180000,
        payoutReleased: 90000,
        payoutOnHold: 60000,
        orders: 12,
        unitsSold: 35,
        averageOrderValue: 15000,
        trendPoints: [10.0, 14.0, 18.0, 22.0, 16.0],
      ),
      SalesRecord(
        label: 'Tue',
        revenue: 210000,
        payoutReleased: 120000,
        payoutOnHold: 45000,
        orders: 15,
        unitsSold: 40,
        averageOrderValue: 14000,
        trendPoints: [16.0, 18.0, 14.0, 19.0, 24.0],
      ),
      SalesRecord(
        label: 'Wed',
        revenue: 160000,
        payoutReleased: 80000,
        payoutOnHold: 50000,
        orders: 10,
        unitsSold: 28,
        averageOrderValue: 15500,
        trendPoints: [8.0, 12.0, 18.0, 16.0, 12.0],
      ),
      SalesRecord(
        label: 'Thu',
        revenue: 240000,
        payoutReleased: 130000,
        payoutOnHold: 65000,
        orders: 18,
        unitsSold: 45,
        averageOrderValue: 16000,
        trendPoints: [12.0, 18.0, 22.0, 28.0, 30.0],
      ),
      SalesRecord(
        label: 'Fri',
        revenue: 300000,
        payoutReleased: 180000,
        payoutOnHold: 70000,
        orders: 20,
        unitsSold: 52,
        averageOrderValue: 17000,
        trendPoints: [20.0, 26.0, 30.0, 34.0, 36.0],
      ),
      SalesRecord(
        label: 'Sat',
        revenue: 265000,
        payoutReleased: 150000,
        payoutOnHold: 60000,
        orders: 17,
        unitsSold: 48,
        averageOrderValue: 15500,
        trendPoints: [18.0, 22.0, 26.0, 30.0, 28.0],
      ),
      SalesRecord(
        label: 'Sun',
        revenue: 195000,
        payoutReleased: 90000,
        payoutOnHold: 65000,
        orders: 13,
        unitsSold: 33,
        averageOrderValue: 15000,
        trendPoints: [12.0, 14.0, 20.0, 24.0, 22.0],
      ),
    ];
  }

  @override
  List<Object?> get props => [
        label,
        revenue,
        payoutReleased,
        payoutOnHold,
        orders,
        unitsSold,
        averageOrderValue,
        trendPoints,
      ];
}
