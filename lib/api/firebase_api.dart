import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kariakoonline_seller/model/store.dart';
import 'package:kariakoonline_seller/model/seller_preferences.dart';

class FirebaseApi {
  static User? firebaseUser = FirebaseAuth.instance.currentUser;

  //Create Seller Account
  static Future<void> createUser(Store store) async {
    final docUser =
        FirebaseFirestore.instance.collection('seller').doc(store.id);

    await docUser.set(store.toJson());
  }

  //Create User Preference
  static Future<void> userPreference(SellerPref userPref) async {
    final docUserPref = FirebaseFirestore.instance
        .collection('seller_preference')
        .doc(userPref.id);

    await docUserPref.set(userPref.toJson());
  }

  //Update User Preference
  static Future<String> updatePreference(SellerPref userPref) async {
    final docUserPref = FirebaseFirestore.instance
        .collection('seller_preference')
        .doc(userPref.id);
    await docUserPref.update(userPref.toJson());
    // return updated id;
    return docUserPref.id;
  }
}
