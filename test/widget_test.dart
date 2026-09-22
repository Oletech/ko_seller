// Smoke test: the app builds its provider graph and shows the splash screen.
//
// Firebase is mocked with `setupFirebaseCoreMocks()` from
// firebase_core_platform_interface's public test surface. An earlier version of
// this test implemented TestFirebaseCoreHostApi by hand, which meant it
// referenced pigeon-generated class names directly and pinned
// firebase_core_platform_interface in dev_dependencies to keep compiling. That
// pin held the Dart side on old pigeon channel names while the native plugin
// moved to namespaced ones, and the released app died at startup with
// "Unable to establish connection on channel". Use the public helper.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kariakoonline_seller/main.dart';
import 'package:kariakoonline_seller/screen/splash.dart';
import 'package:kariakoonline_seller/services/firebase_session_service.dart';
import 'package:kariakoonline_seller/services/local_storage_service.dart';
import 'package:kariakoonline_seller/services/marketplace_order_service.dart';
import 'package:kariakoonline_seller/services/marketplace_product_service.dart';
import 'package:kariakoonline_seller/services/otp_service.dart';
import 'package:kariakoonline_seller/services/push_notification_service.dart';
import 'package:kariakoonline_seller/services/seller_payment_method_service.dart';
import 'package:kariakoonline_seller/services/seller_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets('App renders splash screen', (WidgetTester tester) async {
    // setupFirebaseCoreMocks already registers the default app.
    await Firebase.initializeApp();

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final sessionService = FirebaseSessionService();

    await tester.pumpWidget(
      KariakooSellerApp(
        storage: storage,
        otpService: OtpService(),
        pushNotificationService: PushNotificationService(),
        sessionService: sessionService,
        sellerProfileService:
            SellerProfileService(sessionService: sessionService),
        sellerPaymentMethodService:
            SellerPaymentMethodService(sessionService: sessionService),
        marketplaceProductService:
            MarketplaceProductService(sessionService: sessionService),
        marketplaceOrderService:
            MarketplaceOrderService(sessionService: sessionService),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);

    // Tear the tree down before the splash timer fires, so the test does not
    // navigate into screens that need a live backend.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
