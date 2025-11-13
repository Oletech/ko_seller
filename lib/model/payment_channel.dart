import 'package:equatable/equatable.dart';

enum PaymentChannelType {
  lipaNamba,
  mpesa,
  tigopesa,
  airtelMoney,
  bankAccount,
  cashPickup,
  crypto,
  custom,
}

extension PaymentChannelTypeX on PaymentChannelType {
  String get label {
    switch (this) {
      case PaymentChannelType.lipaNamba:
        return 'Lipa Namba';
      case PaymentChannelType.mpesa:
        return 'M-PESA';
      case PaymentChannelType.tigopesa:
        return 'Tigo Pesa';
      case PaymentChannelType.airtelMoney:
        return 'Airtel Money';
      case PaymentChannelType.bankAccount:
        return 'Bank';
      case PaymentChannelType.cashPickup:
        return 'Cash Pickup';
      case PaymentChannelType.crypto:
        return 'Crypto';
      case PaymentChannelType.custom:
        return 'Custom';
    }
  }

  static PaymentChannelType fromString(String raw) {
    return PaymentChannelType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => PaymentChannelType.custom,
    );
  }
}

class PaymentChannel extends Equatable {
  final String id;
  final PaymentChannelType type;
  final String displayName;
  final String accountNumber;
  final String instructions;
  final bool isPrimary;

  const PaymentChannel({
    required this.id,
    required this.type,
    required this.displayName,
    required this.accountNumber,
    this.instructions = '',
    this.isPrimary = false,
  });

  PaymentChannel copyWith({
    String? id,
    PaymentChannelType? type,
    String? displayName,
    String? accountNumber,
    String? instructions,
    bool? isPrimary,
  }) {
    return PaymentChannel(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      accountNumber: accountNumber ?? this.accountNumber,
      instructions: instructions ?? this.instructions,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'displayName': displayName,
      'accountNumber': accountNumber,
      'instructions': instructions,
      'isPrimary': isPrimary,
    };
  }

  factory PaymentChannel.fromJson(Map<String, dynamic> json) {
    return PaymentChannel(
      id: json['id'] as String,
      type: PaymentChannelTypeX.fromString(
        (json['type'] ?? PaymentChannelType.custom.name) as String,
      ),
      displayName: json['displayName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        displayName,
        accountNumber,
        instructions,
        isPrimary,
      ];
}
