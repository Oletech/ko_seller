import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_verification_code/flutter_verification_code.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';
import '../utils/style.dart';
import 'home.dart';

class VerificationScreen extends StatefulWidget {
  static const routeName = '/verify';
  const VerificationScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String _otp = '';
  bool _isLoading = false;
  Timer? _timer;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  Future<void> _verify() async {
    if (_otp.length < 4) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _isLoading = true;
    });
    final success = await auth.verifyOtp(_otp);
    setState(() {
      _isLoading = false;
    });
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid or expired OTP, jaribu tena.'),
          backgroundColor: sellerRed,
        ),
      );
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    await auth.requestOtp(widget.phoneNumber);
    _startTimer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP mpya: ${auth.debugCode}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              FadeInDown(
                child: SizedBox(
                  height: 200,
                  child: Image.asset('assets/images/seller-otp.jpg'),
                ),
              ),
              const SizedBox(height: 24),
              FadeInDown(
                delay: const Duration(milliseconds: 150),
                child: const Text(
                  'Verification',
                  style: TextStyle(
                    fontFamily: 'Impact',
                    fontSize: 30,
                    color: sellerGreen,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeInDown(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  'Tumepeleka msimbo wa tarakimu 4 kwa ${widget.phoneNumber}\n'
                  'Msimbo unatumika kujenga uhusiano wa Alice na Bob salama.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 32),
              FadeInDown(
                delay: const Duration(milliseconds: 350),
                child: Column(
                  children: [
                    VerificationCode(
                      length: 4,
                      textStyle: const TextStyle(fontSize: 20),
                      underlineColor: sellerGreen,
                      keyboardType: TextInputType.number,
                      onCompleted: (value) => _otp = value,
                      onEditing: (_) {},
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Demo OTP: ${auth.debugCode ?? 'Pending...'}',
                      style: const TextStyle(color: sellerGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FadeInDown(
                delay: const Duration(milliseconds: 450),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _countdown > 0
                          ? 'Resend in $_countdown s'
                          : 'Didn\'t receive code?',
                      style: const TextStyle(color: sellerGray),
                    ),
                    TextButton(
                      onPressed: _countdown > 0 ? null : _resend,
                      child: const Text(
                        'Resend',
                        style: TextStyle(color: sellerGreen),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FadeInDown(
                delay: const Duration(milliseconds: 550),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sellerRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _verify,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Verify & Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
