import 'package:flutter/material.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';

class LoaderScreen extends StatelessWidget {
  const LoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: AppColor.red));
  }
}
