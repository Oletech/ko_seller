import 'package:kariakoonline_seller/utils/utils.dart';

class Store {
  String? id;
  String? businessName;
  String? storeName;
  String? businessType;
  String? logo;
  String? phone;
  String? email;
  String? storeAddress;
  String? knowsAbout;
  String? areaServed;
  int? follower;
  List<String>? brand;
  bool? sellerStatus;
  bool? hasOfferCatalog;
  DateTime? createdAt;

  Store({
    this.id,
    this.businessName,
    this.storeName,
    this.businessType,
    this.logo,
    this.phone,
    this.email,
    this.storeAddress,
    this.knowsAbout,
    this.areaServed,
    this.follower,
    this.brand,
    this.sellerStatus,
    this.hasOfferCatalog,
    this.createdAt,
  });

  Store copy({
    String? id,
    String? name,
    String? storeName,
    String? type,
    String? logo,
    String? phone,
    String? email,
    String? storeAddress,
    String? about,
    String? areaServed,
    int? follower,
    List<String>? brand,
    bool? sellerStatus,
    bool? hasOfferCatalog,
    DateTime? createdAt,
  }) =>
      Store(
        id: id ?? this.id,
        businessName: name ?? this.businessName,
        storeName: storeName ?? this.storeName,
        businessType: type ?? this.businessType,
        logo: logo ?? this.logo,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        storeAddress: storeAddress ?? this.storeAddress,
        knowsAbout: about ?? this.knowsAbout,
        areaServed: areaServed ?? this.areaServed,
        follower: follower ?? this.follower,
        brand: brand ?? this.brand,
        sellerStatus: sellerStatus ?? this.sellerStatus,
        hasOfferCatalog: hasOfferCatalog ?? this.hasOfferCatalog,
        createdAt: createdAt ?? this.createdAt,
      );

  static Store fromJson(Map<String, dynamic> json) => Store(
        id: json['sellerid'],
        businessName: json['BusinessName'],
        storeName: json['storeName'],
        businessType: json['BusinessType'],
        logo: json['logo'],
        phone: json['phone'],
        email: json['email'],
        storeAddress: json['storeAddress'],
        knowsAbout: json['knowsAbout'],
        areaServed: json['areaServed'],
        brand: List.from(json['brand']),
        sellerStatus: json['sellerStatus'],
        follower: json['follower'],
        hasOfferCatalog: json['hasOfferCatalog'],
        createdAt: Utils.toDateTime(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'sellerid': id,
        'BusinessName': businessName,
        'storeName': storeName,
        'BusinessType': businessType,
        'logo': logo,
        'phone': phone,
        'email': email,
        'storeAddress': storeAddress,
        'knowsAbout': knowsAbout,
        'areaServed': areaServed,
        'brand': brand!.map((e) => e),
        'sellerStatus': sellerStatus,
        'follower': follower,
        'hasOfferCatalog': hasOfferCatalog,
        'createdAt': Utils.fromDateTimeToJson(createdAt),
      };
}
