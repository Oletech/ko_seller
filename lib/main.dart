import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'provider/auth_provider.dart';
import 'provider/notification_provider.dart';
import 'provider/order_provider.dart';
import 'provider/product_provider.dart';
import 'screen/splash.dart';
import 'services/firebase_session_service.dart';
import 'services/local_storage_service.dart';
import 'services/marketplace_order_service.dart';
import 'services/marketplace_product_service.dart';
import 'services/otp_service.dart';
import 'services/push_notification_service.dart';
import 'services/seller_payment_method_service.dart';
import 'services/seller_profile_service.dart';
import 'utils/route.dart';
import 'utils/style.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge is enforced from targetSdk 35 and cannot be opted out of at
  // 36, so the system bars are transparent and draw over the app. The seller
  // UI is light, so the icons have to be dark or they disappear.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final otpService = OtpService();
  final pushNotificationService = PushNotificationService();
  final sessionService = FirebaseSessionService();
  final sellerProfileService =
      SellerProfileService(sessionService: sessionService);
  final sellerPaymentMethodService =
      SellerPaymentMethodService(sessionService: sessionService);
  final marketplaceProductService =
      MarketplaceProductService(sessionService: sessionService);
  final marketplaceOrderService =
      MarketplaceOrderService(sessionService: sessionService);

  runApp(
    KariakooSellerApp(
      storage: storage,
      otpService: otpService,
      pushNotificationService: pushNotificationService,
      sessionService: sessionService,
      sellerProfileService: sellerProfileService,
      sellerPaymentMethodService: sellerPaymentMethodService,
      marketplaceProductService: marketplaceProductService,
      marketplaceOrderService: marketplaceOrderService,
    ),
  );
}

class KariakooSellerApp extends StatelessWidget {
  const KariakooSellerApp({
    super.key,
    required this.storage,
    required this.otpService,
    required this.pushNotificationService,
    required this.sessionService,
    required this.sellerProfileService,
    required this.sellerPaymentMethodService,
    required this.marketplaceProductService,
    required this.marketplaceOrderService,
  });

  final LocalStorageService storage;
  final OtpService otpService;
  final PushNotificationService pushNotificationService;
  final FirebaseSessionService sessionService;
  final SellerProfileService sellerProfileService;
  final SellerPaymentMethodService sellerPaymentMethodService;
  final MarketplaceProductService marketplaceProductService;
  final MarketplaceOrderService marketplaceOrderService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            storage: storage,
            otpService: otpService,
            sessionService: sessionService,
            sellerProfileService: sellerProfileService,
            sellerPaymentMethodService: sellerPaymentMethodService,
            pushNotificationService: pushNotificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(
            storage: storage,
            pushNotificationService: pushNotificationService,
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
          create: (_) => ProductProvider(
            storage: storage,
            remoteService: marketplaceProductService,
          ),
          update: (_, auth, previous) {
            final provider = previous ??
                ProductProvider(
                  storage: storage,
                  remoteService: marketplaceProductService,
                );
            provider.bindSeller(auth.profile);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<AuthProvider, ProductProvider,
            OrderProvider>(
          create: (context) => OrderProvider(
            notificationProvider: context.read<NotificationProvider>(),
            remoteService: marketplaceOrderService,
          ),
          update: (context, auth, products, previous) {
            final provider = previous ??
                OrderProvider(
                  notificationProvider: context.read<NotificationProvider>(),
                  remoteService: marketplaceOrderService,
                );
            provider.updateNotificationProvider(
              context.read<NotificationProvider>(),
            );
            provider.bindSellerContext(auth.profile, products.products);
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
