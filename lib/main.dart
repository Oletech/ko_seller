import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kariakoonline_seller/provider/auth_provider.dart';
import 'package:kariakoonline_seller/screen/splash.dart';
import 'package:kariakoonline_seller/utils/route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is t  e root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Kariakoonline Seller',
        theme: ThemeData(
          primarySwatch: Colors.red,
        ),
        home: const SplashScreen(),
        routes: routes,
      ),
    );
  }
}
