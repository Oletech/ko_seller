import 'package:flutter/material.dart';

import '../screen/home.dart';
import '../screen/login.dart';
import '../screen/new_product.dart';
import '../screen/splash.dart';
import '../screen/verification.dart';

Map<String, WidgetBuilder> routes = {
  SplashScreen.routeName: (_) => const SplashScreen(),
  HomeScreen.routeName: (_) => const HomeScreen(),
  LoginScreen.routeName: (_) => const LoginScreen(),
  NewProductScreen.routeName: (_) => const NewProductScreen(),
  VerificationScreen.routeName: (context) {
    final phone = ModalRoute.of(context)?.settings.arguments as String? ?? '';
    return VerificationScreen(phoneNumber: phone);
  },
};
