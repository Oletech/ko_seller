import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider/auth_provider.dart';
import 'provider/notification_provider.dart';
import 'provider/order_provider.dart';
import 'provider/product_provider.dart';
import 'screen/splash.dart';
import 'services/local_storage_service.dart';
import 'services/otp_service.dart';
import 'utils/route.dart';
import 'utils/style.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final otpService = OtpService();

  runApp(
    KariakooSellerApp(
      storage: storage,
      otpService: otpService,
    ),
  );
}

class KariakooSellerApp extends StatelessWidget {
  const KariakooSellerApp({
    super.key,
    required this.storage,
    required this.otpService,
  });

  final LocalStorageService storage;
  final OtpService otpService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            storage: storage,
            otpService: otpService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(storage: storage),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(storage: storage),
        ),
        ChangeNotifierProxyProvider<NotificationProvider, OrderProvider>(
          create: (context) => OrderProvider(
            notificationProvider: context.read<NotificationProvider>(),
          ),
          update: (_, notificationProvider, previous) {
            final provider = previous ??
                OrderProvider(notificationProvider: notificationProvider);
            provider.updateNotificationProvider(notificationProvider);
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Kariakoonline Seller',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: sellerRed,
            primary: sellerRed,
            secondary: sellerGreen,
          ),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Muli',
          textTheme: const TextTheme(
            headlineMedium: TextStyle(
              fontFamily: 'Impact',
              fontSize: 28,
              color: sellerGreen,
            ),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: routes,
      ),
    );
  }
}
