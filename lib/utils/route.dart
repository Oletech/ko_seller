import 'package:flutter/material.dart';
import 'package:kariakoonline_seller/screen/account.dart';
import 'package:kariakoonline_seller/screen/favorite.dart';
import 'package:kariakoonline_seller/screen/home.dart';
import 'package:kariakoonline_seller/screen/login.dart';
import 'package:kariakoonline_seller/screen/new_product.dart';
import 'package:kariakoonline_seller/screen/notifications.dart';
import 'package:kariakoonline_seller/screen/order.dart';
import 'package:kariakoonline_seller/screen/products.dart';
import 'package:kariakoonline_seller/screen/verification.dart';

Map<String, WidgetBuilder> routes = {
  HomeScreen.routeName: (context) => const HomeScreen(),
  AccountScreen.routeName: (context) => const AccountScreen(),
  OrderScreen.routeName: (context) => const OrderScreen(),
  NotificationScreen.routeName: (context) => const NotificationScreen(),
  ProductScreen.routeName: (context) => const ProductScreen(),
  NewProductScreen.routeName: (context) => const NewProductScreen(),
  FavoriteScreen.routeName: (context) => const FavoriteScreen(),
  LoginScreen.routeName: (context) => const LoginScreen(),
  Verificatoin.routeName: (context) => const Verificatoin(),
};
