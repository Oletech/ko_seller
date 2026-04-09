import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'payment_channel.dart';

class SellerProfile extends Equatable {
  final String id;
  final String firestoreDocId;
  final String phoneNumber;
  final String email;
  final String displayName;
  final String storeName;
  final String businessType;
  final String bio;
  final double inventoryValue;
  final double salesValue;
  final int totalOrders;
  final String avatarUrl;
  final int followerCount;
  final List<PaymentChannel> paymentChannels;
  final DateTime updatedAt;
  final bool notificationsEnabled;
  final bool sellerStatus;

  const SellerProfile({
    required this.id,
    required this.firestoreDocId,
    required this.phoneNumber,
    required this.email,
    required this.displayName,
    required this.storeName,
    required this.businessType,
    required this.bio,
    required this.inventoryValue,
    required this.salesValue,
    required this.totalOrders,
    required this.avatarUrl,
    required this.followerCount,
    required this.paymentChannels,
    required this.updatedAt,
    required this.notificationsEnabled,
    required this.sellerStatus,
  });

  factory SellerProfile.empty(String phoneNumber) {
    return SellerProfile(
      id: '',
      firestoreDocId: '',
      phoneNumber: phoneNumber,
      email: '',
      displayName: '',
      storeName: '',
      businessType: 'General',
      bio: 'Let customers know what makes your store special.',
      inventoryValue: 0,
      salesValue: 0,
      totalOrders: 0,
      avatarUrl: '',
      followerCount: 0,
      paymentChannels: const [],
      updatedAt: DateTime.now(),
      notificationsEnabled: true,
      sellerStatus: true,
    );
  }

  bool get hasCompletedSetup =>
      displayName.isNotEmpty && storeName.isNotEmpty && businessType.isNotEmpty;

  String get productSellerId => id.isNotEmpty ? id : firestoreDocId;

  List<String> get productSellerIds => {
        if (id.isNotEmpty) id,
        if (firestoreDocId.isNotEmpty) firestoreDocId,
      }.toList(growable: false);

  SellerProfile copyWith({
    String? id,
    String? firestoreDocId,
    String? phoneNumber,
    String? email,
    String? displayName,
    String? storeName,
    String? businessType,
    String? bio,
    double? inventoryValue,
    double? salesValue,
    int? totalOrders,
    String? avatarUrl,
    int? followerCount,
    List<PaymentChannel>? paymentChannels,
    DateTime? updatedAt,
    bool? notificationsEnabled,
    bool? sellerStatus,
  }) {
    return SellerProfile(
      id: id ?? this.id,
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      storeName: storeName ?? this.storeName,
      businessType: businessType ?? this.businessType,
      bio: bio ?? this.bio,
      inventoryValue: inventoryValue ?? this.inventoryValue,
      salesValue: salesValue ?? this.salesValue,
      totalOrders: totalOrders ?? this.totalOrders,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      followerCount: followerCount ?? this.followerCount,
      paymentChannels: paymentChannels ?? this.paymentChannels,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      sellerStatus: sellerStatus ?? this.sellerStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firestoreDocId': firestoreDocId,
      'phoneNumber': phoneNumber,
      'email': email,
      'displayName': displayName,
      'storeName': storeName,
      'businessType': businessType,
      'bio': bio,
      'inventoryValue': inventoryValue,
      'salesValue': salesValue,
      'totalOrders': totalOrders,
      'avatarUrl': avatarUrl,
      'followerCount': followerCount,
      'paymentChannels': paymentChannels.map((e) => e.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
      'sellerStatus': sellerStatus,
    };
  }

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      id: json['id'] as String? ?? '',
      firestoreDocId: json['firestoreDocId'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      storeName: json['storeName'] as String? ?? '',
      businessType: json['businessType'] as String? ?? 'General',
      bio: json['bio'] as String? ?? '',
      inventoryValue: (json['inventoryValue'] as num?)?.toDouble() ?? 0,
      salesValue: (json['salesValue'] as num?)?.toDouble() ?? 0,
      totalOrders: json['totalOrders'] as int? ?? 0,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      followerCount: json['followerCount'] as int? ?? 0,
      paymentChannels: (json['paymentChannels'] as List<dynamic>? ?? [])
          .map((e) => PaymentChannel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      sellerStatus: json['sellerStatus'] as bool? ?? true,
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory SellerProfile.fromRawJson(String raw) =>
      SellerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
        id,
        firestoreDocId,
        phoneNumber,
        email,
        displayName,
        storeName,
        businessType,
        bio,
        inventoryValue,
        salesValue,
        totalOrders,
        avatarUrl,
        followerCount,
        paymentChannels,
        updatedAt,
        notificationsEnabled,
        sellerStatus,
      ];
}
