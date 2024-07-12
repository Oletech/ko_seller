import 'package:flutter/material.dart';
import 'package:kariakoonline_seller/api/firebase_api.dart';
import 'package:kariakoonline_seller/model/seller_preferences.dart';

class PreferenceProvider with ChangeNotifier {
  List<SellerPref> _userPref = [];

  List<SellerPref> get userPreference {
    return [..._userPref];
  }

  void addPreference(SellerPref userPref) =>
      FirebaseApi.userPreference(userPref);

  void updatePreference(SellerPref userPref) =>
      FirebaseApi.updatePreference(userPref);

  void fetchPreference(List<SellerPref>? userPref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userPref = userPref!;
      notifyListeners();
    });
  }
}
