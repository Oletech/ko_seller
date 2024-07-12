import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';

class NewProductScreen extends StatefulWidget {
  static String routeName = '../new_product_screen';
  const NewProductScreen({Key? key}) : super(key: key);

  @override
  State<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<NewProductScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(),
    );
  }
}
