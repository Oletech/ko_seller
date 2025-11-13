import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum EscrowState {
  awaitingFunding,
  funded,
  awaitingDelivery,
  awaitingBuyerConfirmation,
  disputeOpened,
  releasedToSeller,
  refundedToBuyer,
}

class EscrowEvent extends Equatable {
  final String title;
  final String message;
  final DateTime timestamp;

  const EscrowEvent({
    required this.title,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory EscrowEvent.fromJson(Map<String, dynamic> json) {
    return EscrowEvent(
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [title, message, timestamp];
}

class EscrowPayment extends Equatable {
  final String id;
  final String buyerName;
  final String sellerName;
  final double amount;
  final EscrowState state;
  final bool proofOfDeliveryReceived;
  final bool proofOfPaymentReceived;
  final List<EscrowEvent> events;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const EscrowPayment({
    required this.id,
    required this.buyerName,
    required this.sellerName,
    required this.amount,
    required this.state,
    required this.proofOfDeliveryReceived,
    required this.proofOfPaymentReceived,
    required this.events,
    required this.createdAt,
    this.resolvedAt,
  });

  factory EscrowPayment.seed({
    required String buyerName,
    required String sellerName,
    required double amount,
    EscrowState state = EscrowState.awaitingFunding,
  }) {
    final now = DateTime.now();
    return EscrowPayment(
      id: const Uuid().v4(),
      buyerName: buyerName,
      sellerName: sellerName,
      amount: amount,
      state: state,
      proofOfDeliveryReceived: false,
      proofOfPaymentReceived: state != EscrowState.awaitingFunding,
      events: [
        EscrowEvent(
          title: 'Order Placed',
          message: '$buyerName initiated payment for $sellerName',
          timestamp: now.subtract(const Duration(minutes: 10)),
        ),
      ],
      createdAt: now.subtract(const Duration(minutes: 15)),
      resolvedAt: null,
    );
  }

  bool get requiresSellerAction {
    return state == EscrowState.awaitingDelivery ||
        state == EscrowState.disputeOpened;
  }

  EscrowPayment copyWith({
    String? id,
    String? buyerName,
    String? sellerName,
    double? amount,
    EscrowState? state,
    bool? proofOfDeliveryReceived,
    bool? proofOfPaymentReceived,
    List<EscrowEvent>? events,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return EscrowPayment(
      id: id ?? this.id,
      buyerName: buyerName ?? this.buyerName,
      sellerName: sellerName ?? this.sellerName,
      amount: amount ?? this.amount,
      state: state ?? this.state,
      proofOfDeliveryReceived:
          proofOfDeliveryReceived ?? this.proofOfDeliveryReceived,
      proofOfPaymentReceived:
          proofOfPaymentReceived ?? this.proofOfPaymentReceived,
      events: events ?? this.events,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyerName': buyerName,
      'sellerName': sellerName,
      'amount': amount,
      'state': state.name,
      'proofOfDeliveryReceived': proofOfDeliveryReceived,
      'proofOfPaymentReceived': proofOfPaymentReceived,
      'events': events.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  factory EscrowPayment.fromJson(Map<String, dynamic> json) {
    return EscrowPayment(
      id: json['id'] as String,
      buyerName: json['buyerName'] as String? ?? '',
      sellerName: json['sellerName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      state: EscrowState.values.firstWhere(
        (element) => element.name == json['state'],
        orElse: () => EscrowState.awaitingFunding,
      ),
      proofOfDeliveryReceived:
          json['proofOfDeliveryReceived'] as bool? ?? false,
      proofOfPaymentReceived: json['proofOfPaymentReceived'] as bool? ?? false,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => EscrowEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.tryParse(json['resolvedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        buyerName,
        sellerName,
        amount,
        state,
        proofOfDeliveryReceived,
        proofOfPaymentReceived,
        events,
        createdAt,
        resolvedAt,
      ];
}
