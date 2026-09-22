import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';
import '../utils/style.dart';
import 'home.dart';
import 'verification.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();
  final PhoneNumber _initialPhoneNumber =
      PhoneNumber(isoCode: 'TZ', dialCode: '+255', phoneNumber: '');
  late PhoneNumber _phoneNumber = _initialPhoneNumber;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final auth = context.read<AuthProvider>();
    final formatted = _phoneNumber.phoneNumber;
    if (formatted == null || formatted.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tafadhali ingiza namba sahihi')),
      );
      return;
    }
    setState(() {
      _sending = true;
    });
    try {
      final autoVerified = await auth.requestOtp(formatted);
      if (!mounted) return;
      if (autoVerified) {
        // Android verified this device without sending an SMS; there is no
        // code to type.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: sellerGreen,
          content: Text(
            'Tumetuma OTP kwa namba yako.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationScreen(phoneNumber: formatted),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: sellerRed,
          content: Text('$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              FadeInDown(
                child: SizedBox(
                  height: size.height * 0.25,
                  child: Image.asset('assets/images/seller-login.jpg'),
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sellerGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: 'Kariakoonline',
                      style: TextStyle(
                        color: sellerGreen,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      children: const [
                        TextSpan(
                          text: ' Seller',
                          style: TextStyle(
                            fontFamily: 'Fascinate-Regular',
                            color: sellerRed,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeInDown(
                delay: const Duration(milliseconds: 150),
                child: const Text(
                  'Ingia kwa namba ya simu',
                  style: TextStyle(
                    fontFamily: 'Impact',
                    fontSize: 30,
                    color: sellerGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              FadeInDown(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  'Weka namba yako ya muuzaji ili upokee msimbo wa uthibitisho (OTP).\n'
                  'Tunatumia uthibitisho huu kulinda akaunti, oda, na malipo ya duka lako.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeInDown(
                delay: const Duration(milliseconds: 350),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (value) => _phoneNumber = value,
                    initialValue: _initialPhoneNumber,
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                    ),
                    textFieldController: _controller,
                    formatInput: false,
                    selectorTextStyle: const TextStyle(
                      fontSize: 16,
                      color: sellerBlack,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      color: sellerBlack,
                    ),
                    inputDecoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Phone Number',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                      hintStyle: TextStyle(
                        fontSize: 16,
                        height: 1.0,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeInDown(
                delay: const Duration(milliseconds: 450),
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
                    onPressed: _sending ? null : _requestOtp,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Tuma Msimbo wa OTP'),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
