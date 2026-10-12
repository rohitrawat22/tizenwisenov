import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../colors/colors.dart';
import '../widgets/custom_text.dart';

Future<void> dialog({
  required BuildContext context,
  Widget? title,
  Widget? content,

  required String cancel,
  required VoidCallback onTap,
  required String okk,
  VoidCallback? cancelOnTap,
  Color cancelButtonBackgroundColor = AppColor.red,
  Color cancelTextColor = AppColor.white,
  Color okkButtonBackgroundColor = AppColor.red,
  Color okkTextColor = AppColor.white,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: title,
        content: content,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(12),
              ),
              backgroundColor: cancelButtonBackgroundColor,
            ),

            onPressed:
                cancelOnTap ??
                () {
                  GoRouter.of(context).pop(true);
                },
            child: CText(cancel, color: cancelTextColor),
          ),
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
