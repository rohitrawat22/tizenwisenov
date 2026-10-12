import 'package:flutter/material.dart';

import '../colors/colors.dart';

bool isLoaderRunning = false;

void loader(BuildContext context) {
  if (isLoaderRunning) {
    return;
  } else {
    isLoaderRunning = true;
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent user from closing by tapping outside
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(color: AppColor.red),
        );
      },
    );
  }
}

void stopLoader(BuildContext context) {
  if (Navigator.of(context, rootNavigator: true).canPop()) {
    isLoaderRunning = false;
    Navigator.of(context, rootNavigator: true).pop();
  }
}

stopLoaderWithoutRoot(BuildContext context) {
  isLoaderRunning = false;
  Navigator.of(context).pop();
}
