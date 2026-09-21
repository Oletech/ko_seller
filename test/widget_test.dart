// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kariakoonline_seller/firebase_options.dart';
import 'package:kariakoonline_seller/main.dart';
import 'package:kariakoonline_seller/services/firebase_session_service.dart';
import 'package:kariakoonline_seller/services/local_storage_service.dart';
import 'package:kariakoonline_seller/services/marketplace_order_service.dart';
import 'package:kariakoonline_seller/services/marketplace_product_service.dart';
import 'package:kariakoonline_seller/services/otp_service.dart';
import 'package:kariakoonline_seller/services/push_notification_service.dart';
import 'package:kariakoonline_seller/services/seller_payment_method_service.dart';
import 'package:kariakoonline_seller/services/seller_profile_service.dart';
import 'package:kariakoonline_seller/screen/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders splash screen', (WidgetTester tester) async {
    TestFirebaseCoreHostApi.setup(_FirebaseCoreTestHostApi());
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.android,
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final otpService = OtpService();
    final sessionService = FirebaseSessionService();

    await tester.pumpWidget(
      KariakooSellerApp(
        storage: storage,
        otpService: otpService,
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
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FirebaseCoreTestHostApi implements TestFirebaseCoreHostApi {
  @override
  Future<List<PigeonInitializeResponse?>> initializeCore() async => [];

  @override
  Future<PigeonInitializeResponse> initializeApp(
    String appName,
    PigeonFirebaseOptions initializeAppRequest,
  ) async {
    return PigeonInitializeResponse(
      name: appName,
      options: initializeAppRequest,
      pluginConstants: {},
    );
  }

  @override
  Future<PigeonFirebaseOptions> optionsFromResource() async {
    return PigeonFirebaseOptions(
      apiKey: DefaultFirebaseOptions.android.apiKey,
      appId: DefaultFirebaseOptions.android.appId,
      messagingSenderId: DefaultFirebaseOptions.android.messagingSenderId,
      projectId: DefaultFirebaseOptions.android.projectId,
    );
  }
}
