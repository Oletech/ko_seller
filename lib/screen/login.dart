import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:kariakoonline_seller/provider/auth_provider.dart';
import 'package:kariakoonline_seller/screen/verification.dart';
import 'package:kariakoonline_seller/utils/style.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  static String routeName = '../login_screen';
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String phoneNumber = '';
  final TextEditingController controller = TextEditingController();
  bool _isLoading = false;
  String verificationId = '';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final authProvider = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Brand Logo
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: const Text(
                    'Seller',
                    style: TextStyle(
                      fontFamily: 'Fascinate-Regular',
                      fontSize: 50,
                      color: sellerRed,
                    ),
                  ),
                ),
                FadeInDown(
                  child: SizedBox(
                    height: 150,
                    child: Image.asset('assets/images/seller-login.jpg'),
                  ),
                ),
                FadeInDown(
                  child: Text(
                    'LOGIN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.grey.shade900,
                      fontFamily: 'Muli',
                    ),
                  ),
                ),
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15.0, horizontal: 20),
                    child: Text(
                      'Enter your phone number to continue, we will send you OTP to verifiy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontFamily: 'Muli',
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                // Phone Number Input with Country Flag and Code
                FadeInDown(
                  delay: const Duration(milliseconds: 400),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black.withOpacity(0.13)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xffeeeeee),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        InternationalPhoneNumberInput(
                          onInputChanged: (PhoneNumber number) {
                            print(number.phoneNumber);
                          },
                          onInputValidated: (bool value) {
                            print(value);
                          },
                          selectorConfig: const SelectorConfig(
                            selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                          ),
                          ignoreBlank: false,
                          autoValidateMode: AutovalidateMode.disabled,
                          selectorTextStyle: TextStyle(color: Colors.black),
                          textFieldController: controller,
                          formatInput: false,
                          maxLength: 9,
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                          cursorColor: Colors.black,
                          inputDecoration: InputDecoration(
                            contentPadding:
                                EdgeInsets.only(bottom: 15, left: 0),
                            border: InputBorder.none,
                            hintText: 'Phone Number',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16),
                          ),
                          onSaved: (PhoneNumber number) {
                            print('On Saved: $number');
                          },
                        ),
                        Positioned(
                          left: 90,
                          top: 8,
                          bottom: 8,
                          child: Container(
                            height: 40,
                            width: 1,
                            color: Colors.black.withOpacity(0.13),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                FadeInDown(
                  delay: const Duration(milliseconds: 600),
                  child: MaterialButton(
                    minWidth: double.infinity,
                    onPressed: () async {
                      setState(() {
                        _isLoading = authProvider.loading;
                      });

                      authProvider.authenticatePhoneNo(context, phoneNumber);

                      Future.delayed(const Duration(seconds: 2), () {
                        setState(() {
                          _isLoading = authProvider.loading;
                        });
                      });
                    },
                    color: sellerRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 30,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              backgroundColor: Colors.white,
                              color: sellerGray,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Request OTP",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
                // Terms of Use and Privacy Policy Links
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: <Widget>[
                //     const Text('By logging in, you agree to our '),
                //     GestureDetector(
                //       onTap: () {
                //         // Navigate to the Terms of Use page
                //       },
                //       child: const Text(
                //         'Terms of Use',
                //         style: TextStyle(
                //           color: sellerGreen,
                //           decoration: TextDecoration.underline,
                //         ),
                //       ),
                //     ),
                //     const Text(' and '),
                //     GestureDetector(
                //       onTap: () {
                //         // Navigate to the Privacy Policy page
                //       },
                //       child: const Text(
                //         'Privacy Policy',
                //         style: TextStyle(
                //           color: sellerGreen,
                //           decoration: TextDecoration.underline,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
