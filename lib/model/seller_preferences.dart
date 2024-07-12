import 'package:kariakoonline_seller/model/usersettings.dart';

class SellerPref {
  String? id;
  String? name;
  String? phone;
  String? image;
  String? onlineImage;
  UserSettings? settings;

  SellerPref({
    this.id,
    this.name,
    this.phone,
    this.image,
    this.onlineImage,
    this.settings = const UserSettings(),
  });

  SellerPref copy({
    String? id,
    String? name,
    String? phone,
    String? image,
    String? onlineImage,
    UserSettings? userSettings,
  }) =>
      SellerPref(
          id: id ?? this.id,
          name: name ?? this.name,
          phone: phone ?? this.phone,
          image: image ?? this.image,
          onlineImage: onlineImage ?? this.onlineImage,
          settings: userSettings ?? this.settings);

  static SellerPref fromJson(Map<String, dynamic> json) => SellerPref(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      image: json['image'],
      onlineImage: json['onlineImage'],
      settings: UserSettings.fromJson(json['settings']));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'image': image,
        'onlineImage': onlineImage,
        'settings': settings!.toJson()
      };
}
