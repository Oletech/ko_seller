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
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = const [
    {
      'title': 'Join the Kariakoo Seller Community',
      'subtitle':
          'Create your seller profile, list products and promotions, and reach local buyers — connect your stall to customers in minutes.',
      'bg': 'assets/images/seller-01.jpg',
    },
    {
      'title': 'Accept Orders & Payments Securely',
      'subtitle':
          'Accept mobile money, cards and escrow-protected payments so funds are held until delivery — reducing fraud and building buyer trust.',
      'bg': 'assets/images/seller-02.jpg',
    },
    {
      'title': 'Grow With Reports & Insights',
      'subtitle':
          'Track sales trends, inventory levels and payout releases with clear reports to make smarter stocking and pricing decisions.',
      'bg': 'assets/images/seller-03.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.authenticated) {
        Future.delayed(const Duration(milliseconds: 900), () {
          _navigateTo(const HomeScreen());
        });
      }
    });
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _handlePrimaryAction() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      _navigateTo(const HomeScreen());
    } else {
      _navigateTo(const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (value) {
              setState(() {
                _currentPage = value;
              });
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    page['bg']!,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: sellerBlack.withOpacity(0.45),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 200),
                        const Text(
                          'Seller',
                          style: TextStyle(
                            fontFamily: 'Fascinate-Regular',
                            fontSize: 48,
                            color: Colors.white,
                          ),
                        ),
                        // const Spacer(),
                        Text(
                          page['title']!,
                          style: const TextStyle(
                            fontFamily: 'Impact',
                            fontSize: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['subtitle']!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 50,
            right: 24,
            child: TextButton(
              onPressed: _handlePrimaryAction,
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: size.width,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentPage == index ? 32 : 10,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? sellerGreen
                              : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
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
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _handlePrimaryAction();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
