import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'payment_channel.dart';

class SellerProfile extends Equatable {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String storeName;
  final String businessType;
  final String bio;
  final double inventoryValue;
  final double salesValue;
  final int totalOrders;
  final String avatarUrl;
  final List<PaymentChannel> paymentChannels;
  final DateTime updatedAt;
  final bool notificationsEnabled;

  const SellerProfile({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    required this.storeName,
    required this.businessType,
    required this.bio,
    required this.inventoryValue,
    required this.salesValue,
    required this.totalOrders,
    required this.avatarUrl,
    required this.paymentChannels,
    required this.updatedAt,
    required this.notificationsEnabled,
  });

  factory SellerProfile.empty(String phoneNumber) {
    return SellerProfile(
      id: const Uuid().v4(),
      phoneNumber: phoneNumber,
      displayName: '',
      storeName: '',
      businessType: 'General',
      bio: 'Let customers know what makes your store special.',
      inventoryValue: 0,
      salesValue: 0,
      totalOrders: 0,
      avatarUrl: '',
      paymentChannels: const [],
      updatedAt: DateTime.now(),
      notificationsEnabled: true,
    );
  }

  bool get hasCompletedSetup =>
      displayName.isNotEmpty && storeName.isNotEmpty && businessType.isNotEmpty;

  SellerProfile copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? storeName,
    String? businessType,
    String? bio,
    double? inventoryValue,
    double? salesValue,
    int? totalOrders,
    String? avatarUrl,
    List<PaymentChannel>? paymentChannels,
    DateTime? updatedAt,
    bool? notificationsEnabled,
  }) {
    return SellerProfile(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      storeName: storeName ?? this.storeName,
      businessType: businessType ?? this.businessType,
      bio: bio ?? this.bio,
      inventoryValue: inventoryValue ?? this.inventoryValue,
      salesValue: salesValue ?? this.salesValue,
      totalOrders: totalOrders ?? this.totalOrders,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      paymentChannels: paymentChannels ?? this.paymentChannels,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'storeName': storeName,
      'businessType': businessType,
      'bio': bio,
      'inventoryValue': inventoryValue,
      'salesValue': salesValue,
      'totalOrders': totalOrders,
      'avatarUrl': avatarUrl,
      'paymentChannels': paymentChannels.map((e) => e.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      storeName: json['storeName'] as String? ?? '',
      businessType: json['businessType'] as String? ?? 'General',
      bio: json['bio'] as String? ?? '',
      inventoryValue: (json['inventoryValue'] as num?)?.toDouble() ?? 0,
      salesValue: (json['salesValue'] as num?)?.toDouble() ?? 0,
      totalOrders: json['totalOrders'] as int? ?? 0,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      paymentChannels: (json['paymentChannels'] as List<dynamic>? ?? [])
          .map((e) => PaymentChannel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory SellerProfile.fromRawJson(String raw) =>
      SellerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        displayName,
        storeName,
        businessType,
        bio,
        inventoryValue,
        salesValue,
        totalOrders,
        avatarUrl,
        paymentChannels,
        updatedAt,
        notificationsEnabled,
      ];
}
