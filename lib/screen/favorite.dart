import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';

class FavoriteScreen extends StatelessWidget {
  static String routeName = '../favorite_screen';
  const FavoriteScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: const [
            Center(
              child: Text("Favorites"),
            )
          ],
        ),
      ),
    );
  }
}
