import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:kariakoonline_seller/screen/login.dart';
import 'package:kariakoonline_seller/utils/style.dart';

class SplashScreen extends StatefulWidget {
  static String routeName = '../splash_screen';
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int currentPage = 0;
  PageController controller = PageController();

  List<Map<String, String>> screenContentList = [
    {
      'title': 'Join the \nKariakoo Seller \nCommunity',
      'subtitle': 'Connect. List. Sell. Thrive.',
      'bg': 'assets/images/seller-01.jpg',
    },
    {
      'title': 'Unlock \nYour Selling \nPotential',
      'subtitle': 'Selling Just Got Easier.',
      'bg': 'assets/images/seller-02.jpg',
    },
    {
      'title': 'Empower \nYour Sales \nJourney',
      'subtitle': 'Tap into a World of Buyers.',
      'bg': 'assets/images/seller-03.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Bg Image
            AnimatedContainer(
              duration: const Duration(seconds: 2000),
              curve: Curves.bounceIn,
              child: Image.asset(
                screenContentList[currentPage]['bg'].toString(),
                width: screenWidth,
                height: screenHeight,
                fit: BoxFit.fill,
              ),
            ),
            // Content Body
            PageView.builder(
                controller: controller,
                itemCount: screenContentList.length,
                onPageChanged: (value) {
                  setState(() {
                    currentPage = value;
                  });
                },
                itemBuilder: (context, index) {
                  return OnBoardContent(
                    title: screenContentList[index]['title'].toString(),
                    subtitle: screenContentList[index]['subtitle'].toString(),
                    pageIndex: index,
                  );
                }),
            // Button
            Positioned(
              bottom: 15,
              right: 15,
              left: 15,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(LoginScreen.routeName);
                    },
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: sellerRed,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        controller.nextPage(
                          duration: const Duration(seconds: 2000),
                          curve: Curves.easeIn,
                        );
                        // setState(() {
                        //   currentPage = currentPage + 1;
                        // });
                      },
                      style: ElevatedButton.styleFrom(
                          primary: sellerRed, shape: const CircleBorder()),
                      child: const Icon(
                        Icons.arrow_forward_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnBoardContent extends StatelessWidget {
  const OnBoardContent({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.pageIndex,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      width: screenWidth,
      height: screenHeight,
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo
          const Text(
            'Seller',
            style: TextStyle(
              fontFamily: 'Fascinate-Regular',
              fontSize: 50,
              color: sellerRed,
            ),
          ),
          const SizedBox(height: 50),
          // Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                width: pageIndex != 0 ? 28 : screenWidth / 8,
                height: 8,
                duration: const Duration(seconds: 2000),
                curve: Curves.easeIn,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: pageIndex == 0 ? sellerGreen : sellerGray,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              AnimatedContainer(
                width: pageIndex != 1 ? 28 : screenWidth / 8,
                height: 8,
                duration: const Duration(seconds: 2000),
                curve: Curves.easeIn,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: pageIndex == 1 ? sellerGreen : sellerGray,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              AnimatedContainer(
                width: pageIndex != 2 ? 28 : screenWidth / 8,
                height: 8,
                duration: const Duration(seconds: 2000),
                curve: Curves.easeIn,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: pageIndex == 2 ? sellerGreen : sellerGray,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 70),
          // Title
          Text(
            title.toString(),
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontFamily: 'Impact',
              fontSize: 30,
              color: sellerGreen,
            ),
          ),
          // SubTitle
          Text(
            subtitle.toString(),
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontFamily: 'Muli',
              fontSize: 16,
              color: sellerBlack,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
