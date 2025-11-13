// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:kariakoonline_seller/main.dart';
import 'package:kariakoonline_seller/services/local_storage_service.dart';
import 'package:kariakoonline_seller/services/otp_service.dart';
import 'package:kariakoonline_seller/screen/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final otpService = OtpService();

    await tester.pumpWidget(
      KariakooSellerApp(
        storage: storage,
        otpService: otpService,
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
