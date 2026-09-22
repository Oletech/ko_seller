// SELLER STYLE

import 'dart:ui';

import 'package:flutter/material.dart';

const sellerRed = Color.fromRGBO(219, 48, 35, 1);
const sellerGreen = Color.fromRGBO(15, 103, 104, 1);
const sellerBlack = Color.fromRGBO(0, 0, 0, 1);
const sellerGray = Color.fromRGBO(93, 93, 93, 1);

// Use this to get a responsive height based on your design's reference height.
double koScreenHeight(inputHeight, BuildContext context) {
  // 812 is the layout height that designer use
  const double originalHeight = 812.0;
  final double screenHeight = MediaQuery.of(context).size.height;
  return (inputHeight / originalHeight) * screenHeight;
}

// Use this to get a responsive width based on your design's reference width.
double koScreenWidth(inputWidth, BuildContext context) {
  // 375 is the layout width that designer use
  const double originalWidth = 375.0;
  final double screenWidth = MediaQuery.of(context).size.width;
  return (inputWidth / originalWidth) * screenWidth;
}

/// Shown from Settings and linked in both store listings. Both stores require
/// a reachable privacy policy for an app that holds an account.
const String kPrivacyPolicyUrl =
    'https://kariakoonline.com/seller-privacy-policy.html';
