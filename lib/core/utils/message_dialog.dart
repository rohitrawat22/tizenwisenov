import 'package:flutter/material.dart';

import '../colors/colors.dart';
import '../widgets/custom_text.dart';

Future<void> messageDialog({
  required BuildContext context,
  Widget? title,
  Widget? content,

  required VoidCallback onTap,
  required String okk,

  Color okkButtonBackgroundColor = AppColor.red,
  Color okkTextColor = AppColor.white,
}) async {
  return showDialog<void>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        title: title,
        content: content,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: okkButtonBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(12),
              ),
            ),
            onPressed: onTap,
            child: CText(okk, color: okkTextColor),
          ),
        ],
      );
    },
  );
}

void dialogWithoutDismisable({
  required BuildContext context,
  Widget? title,
  Widget? content,

  required VoidCallback onTap,
  required String okk,

  Color okkButtonBackgroundColor = AppColor.red,
  Color okkTextColor = AppColor.white,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: title,
          content: content,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: okkButtonBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(12),
                ),
              ),
              onPressed: onTap,
              child: CText(okk, color: okkTextColor),
            ),
          ],
        ),
      );
    },
  );
}
