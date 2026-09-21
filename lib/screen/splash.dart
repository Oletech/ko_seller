import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';
import '../utils/style.dart';
import 'home.dart';
import 'login.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        _navigateTo(
            auth.isAuthenticated ? const HomeScreen() : const LoginScreen());
      });
    });
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            const Center(
              child: Text(
                'Seller',
                style: TextStyle(
                  fontFamily: 'Fascinate-Regular',
                  fontSize: 56,
                  color: sellerGreen,
                ),
              ),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: 28,
              child: Image.asset(
                'assets/images/kariakoonline.png',
                height: 18,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
