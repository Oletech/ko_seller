// ignore_for_file: prefer_function_declarations_over_variables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kariakoonline_seller/model/store.dart';
import 'package:kariakoonline_seller/model/seller_preferences.dart';
import 'package:kariakoonline_seller/provider/preference_provider.dart';
import 'package:kariakoonline_seller/screen/home.dart';
import 'package:kariakoonline_seller/screen/verification.dart';
import 'package:kariakoonline_seller/utils/style.dart';
import 'package:kariakoonline_seller/utils/user_preferences.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Status {
  Uninitialized,
  Authenticated,
  Authenticating,
  Unauthenticated,
  AuthenticatingCode,
}

class AuthProvider with ChangeNotifier {
  static const LOGGED_IN = "loggedIn";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String? verificationId;
  String? smsOTP;
  bool loading = false;
  bool loggedIn = false;
  Status _status = Status.Uninitialized;
  Store? _store;
  SellerPref? _sellerPref;
  // SellerPreferences pref = SellerPreferences();

  //getter
  Store? get storeModel => _store;
  Status? get status => _status;
  User? get user => _user;

  // AuthProvider.initialize() {
  //   readPreference();
  // }

  Future<void> readPreference() async {
    await Future.delayed(const Duration(seconds: 3)).then((value) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      loggedIn = prefs.getBool(LOGGED_IN) ?? false;
      _status = Status.Authenticated;
      if (loggedIn == true) {
        _user = _auth.currentUser;
        notifyListeners();
        return;
      }
      _status = Status.Unauthenticated;
      notifyListeners();
    });
  }

  void _createStore({
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
  }) {
    _store!.toJson();
  }

  Future<void> authenticatePhoneNo(
      BuildContext context, String phoneNumber) async {
    final phone = phoneNumber;
    loading = true;
    final PhoneVerificationCompleted verified = (AuthCredential authResult) {
      _auth.signInWithCredential(authResult);
      // Seller is signed in
      _status = Status.Authenticated;
    };

    final PhoneVerificationFailed verificationfailed =
        (FirebaseAuthException authException) {
      if (authException.code == 'invalid-phone-number') {
        _status = Status.Unauthenticated;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: sellerRed,
            duration: Duration(seconds: 2),
            content: Text(
              'The provided phone number is not valid.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontFamily: 'Muli',
              ),
            ),
          ),
        );
      }
    };

    final PhoneCodeSent smsSent = (String verId, [int? forceResend]) {
      _status = Status.Authenticating;
      this.verificationId = verId;
    };

    final PhoneCodeAutoRetrievalTimeout autoTimeout = (String verId) {
      this.verificationId = verId;
    };

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 120),
        verificationCompleted: verified,
        verificationFailed: verificationfailed,
        codeSent: smsSent,
        codeAutoRetrievalTimeout: autoTimeout,
      );
      Navigator.pushNamed(context, Verificatoin.routeName);
    } catch (e) {
      loading = false;
      print('Phone verification catched error: $e');
      notifyListeners();
    }
  }

  signIn(BuildContext context, GlobalKey scaffoldState, String smsOTP) async {
    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId.toString(), smsCode: smsOTP);
      final UserCredential user = await _auth.signInWithCredential(credential);
      final User? currentUser = _auth.currentUser;
      assert(user.user?.uid == currentUser!.uid);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool(LOGGED_IN, true);

      _store = _store!.copy(
        id: _user!.uid,
        phone: _user!.phoneNumber.toString(),
        sellerStatus: true,
        createdAt: DateTime.now(),
      );

      _sellerPref = _sellerPref!.copy(
        id: _user!.uid,
        image: '',
        name: '',
        phone: _user!.phoneNumber.toString(),
        onlineImage: '',
      );

      loggedIn = true;

      FirebaseFirestore.instance
          .collection('seller_preference')
          .doc(_user!.uid)
          .get()
          .then(
        (response) {
          if (response.data() == null) {
            UserPreferences.setUser(_sellerPref);
            print('Not Exist Online');
            //add to firebase
            final prefProvider = Provider.of<PreferenceProvider>(context);
            prefProvider.addPreference(_sellerPref!);
          } else {
            SellerPref userPref = SellerPref.fromJson(response.data()!);
            UserPreferences.setUser(userPref);
            print('Exist Online');
          }
        },
      );

      if (user.user != null) {
        if (_store == null) {
          _createStore(
            id: _user!.uid,
            name: '',
            storeName: '',
            type: '',
            logo: '',
            phone: user.user!.phoneNumber,
            email: '',
            storeAddress: '',
            about: '',
            areaServed: '',
            brand: [],
            sellerStatus: true,
            follower: 0,
            hasOfferCatalog: null,
            createdAt: DateTime.now(),
          );
        }
        loading = false;
        // Navigator.of(context).pop();
        Navigator.popAndPushNamed(context, HomeScreen.routeName);
      }
      loading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            backgroundColor: sellerRed,
            content: Text(
              'Invalid verification code',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontFamily: 'Muli',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          backgroundColor: sellerRed,
          content: Text(
            'OTP Code Expired',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontFamily: 'Muli',
            ),
          ),
        ),
      );
    }
  }
}
