import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// What the marketplace owes (or has already paid) a seller for one released
/// order. Written by the `releaseSellerPayout` step of escrow release and
/// closed by the `markPayoutSettled` admin callable; sellers can read their
/// own rows but never write them.
enum SellerPayoutStatus { pendingSettlement, missingPayoutMethod, settled }

extension SellerPayoutStatusX on SellerPayoutStatus {
  String get label {
    switch (this) {
      case SellerPayoutStatus.pendingSettlement:
        return 'Being sent';
      case SellerPayoutStatus.missingPayoutMethod:
        return 'Add a payout account';
      case SellerPayoutStatus.settled:
        return 'Paid out';
    }
  }

  static SellerPayoutStatus fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'settled':
        return SellerPayoutStatus.settled;
      case 'missing_payout_method':
        return SellerPayoutStatus.missingPayoutMethod;
      default:
        return SellerPayoutStatus.pendingSettlement;
    }
  }
}

class SellerPayout extends Equatable {
  const SellerPayout({
    required this.id,
    required this.orderNumber,
    required this.orderDocumentId,
    required this.currency,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.status,
    required this.createdAt,
    this.settledAt,
    this.settlementReference = '',
    this.destinationLabel = '',
  });

  final String id;
  final String orderNumber;
  final String orderDocumentId;
  final String currency;
  final double grossAmount;
  final double commissionAmount;
  final double netAmount;
  final SellerPayoutStatus status;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String settlementReference;
  final String destinationLabel;

  bool get isSettled => status == SellerPayoutStatus.settled;

  factory SellerPayout.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final destination = data['destination'];
    final destinationMap = destination is Map
        ? destination.map((key, value) => MapEntry('$key', value))
        : const <String, dynamic>{};

    return SellerPayout(
      id: '${data['payoutId'] ?? doc.id}',
      orderNumber: '${data['orderNumber'] ?? ''}',
      orderDocumentId: '${data['orderDocumentId'] ?? ''}',
      currency: '${data['currency'] ?? 'TZS'}',
      grossAmount: _toDouble(data['grossAmount']),
      commissionAmount: _toDouble(data['commissionAmount']),
      netAmount: _toDouble(data['netAmount']),
      status: SellerPayoutStatusX.fromString('${data['status'] ?? ''}'),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      settledAt: _toDateTime(data['settledAt']),
      settlementReference: '${data['settlementReference'] ?? ''}',
      destinationLabel: [
        '${destinationMap['displayName'] ?? ''}'.trim(),
        '${destinationMap['accountNumber'] ?? ''}'.trim(),
      ].where((value) => value.isNotEmpty).join(' · '),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [id, status, netAmount, settledAt];
}
