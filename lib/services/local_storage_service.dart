import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/app_notification.dart';
import '../model/product_item.dart';
import '../model/seller_profile.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  static const _sellerKey = 'seller_profile';
  static const _productsKey = 'seller_products';
  static const _notificationsKey = 'seller_notifications';

  final SharedPreferences _prefs;

  SellerProfile? readSellerProfile() {
    final raw = _prefs.getString(_sellerKey);
    if (raw == null) return null;
    try {
      return SellerProfile.fromRawJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSellerProfile(SellerProfile profile) async {
    await _prefs.setString(_sellerKey, profile.toRawJson());
  }

  List<ProductItem> readProducts() {
    final raw = _prefs.getStringList(_productsKey);
    if (raw == null) return [];
    return raw
        .map(
          (item) =>
              ProductItem.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> saveProducts(List<ProductItem> products) async {
    final payload =
        products.map((p) => jsonEncode(p.toJson())).toList(growable: false);
    await _prefs.setStringList(_productsKey, payload);
  }

  List<AppNotification> readNotifications() {
    final raw = _prefs.getStringList(_notificationsKey);
    if (raw == null) return [];
    return raw
        .map(
          (item) => AppNotification.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> saveNotifications(List<AppNotification> notifications) async {
    final payload = notifications
        .map((n) => jsonEncode(n.toJson()))
        .toList(growable: false);
    await _prefs.setStringList(_notificationsKey, payload);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_sellerKey);
    await _prefs.remove(_productsKey);
    await _prefs.remove(_notificationsKey);
  }
}
