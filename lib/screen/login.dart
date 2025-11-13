import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';
import '../utils/style.dart';
import 'verification.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();
  PhoneNumber _phoneNumber =
      PhoneNumber(isoCode: 'TZ', dialCode: '+255', phoneNumber: '');
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
    await auth.requestOtp(formatted);
    setState(() {
      _sending = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,
        content: Text(
          'OTP ya majaribio: ${auth.debugCode}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerificationScreen(phoneNumber: formatted),
      ),
    );
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
                delay: const Duration(milliseconds: 150),
                child: const Text(
                  'Ingia kwa OTP',
                  style: TextStyle(
                    fontFamily: 'Impact',
                    fontSize: 32,
                    color: sellerGreen,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInDown(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  'Tunakutumia msimbo wa dakika moja kuthibitisha.\n'
                  'Kariakoo Online hutumia OTP salama kati ya Bob na Alice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeInDown(
                delay: const Duration(milliseconds: 350),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (value) => _phoneNumber = value,
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                    ),
                    textFieldController: _controller,
                    formatInput: false,
                    inputDecoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Phone Number',
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
                        : const Text('Request OTP'),
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
