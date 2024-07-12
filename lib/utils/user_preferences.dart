import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:kariakoonline_seller/model/seller_preferences.dart';
import 'package:kariakoonline_seller/model/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Store
class StorePreferences {
  static SharedPreferences? _preferences;

  static User? user = FirebaseAuth.instance.currentUser;
  static String _temporaryUId = Uuid().v4().toString();
  static String _userId = user == null ? _temporaryUId : user!.uid;

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setUser(Store? user) async {
    final json = jsonEncode(user!.toJson());
    final String uId = user.id!;
    await _preferences!.setString(_userId, json);
  }

  static Store? getUser(String userId) {
    try {
      final json = _preferences!.getString(userId);
      final userIn = json == null ? null : Store.fromJson(jsonDecode(json));
      return userIn;
    } catch (e) {
      print('Get user pref error $e');
    }
    return null;
  }

  //set and get maltiple user from user preference Note: incase device have multiple account

  static Future addUser(Store user) async {
    try {
      final idUsers = _preferences!.getStringList(_userId) ?? <String>[];
      final newIdUser = List.of(idUsers)..add(user.id!);

      await _preferences!.setStringList(_userId, newIdUser);
    } catch (e) {
      print('Get user pref error $e');
    }
  }

  static List<Store?> fetchUser() {
    final idUsers = _preferences!.getStringList(_userId);

    if (idUsers == null) {
      return <Store>[];
    } else {
      return idUsers.map<Store?>(getUser).toList();
    }
  }
}

// User
class UserPreferences {
  static SharedPreferences? _preferences;

  static User? user = FirebaseAuth.instance.currentUser;
  static String _temporaryUId = Uuid().v4().toString();
  static String _userId = user == null ? _temporaryUId : user!.uid;

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setUser(SellerPref? user) async {
    final json = jsonEncode(user!.toJson());
    final String uId = user.id!;
    await _preferences!.setString(_userId, json);
  }

  static SellerPref? getUser(String userId) {
    try {
      final json = _preferences!.getString(userId);
      final userIn =
          json == null ? null : SellerPref.fromJson(jsonDecode(json));
      return userIn;
    } catch (e) {
      print('Get user pref error $e');
    }
    return null;
  }

  //set and get maltiple user from user preference Note: incase device have multiple account

  static Future addUser(SellerPref user) async {
    try {
      final idUsers = _preferences!.getStringList(_userId) ?? <String>[];
      final newIdUser = List.of(idUsers)..add(user.id!);

      await _preferences!.setStringList(_userId, newIdUser);
    } catch (e) {
      print('Get user pref error $e');
    }
  }

  static List<SellerPref?> fetchUser() {
    final idUsers = _preferences!.getStringList(_userId);

    if (idUsers == null) {
      return <SellerPref>[];
    } else {
      return idUsers.map<SellerPref?>(getUser).toList();
    }
  }
}
