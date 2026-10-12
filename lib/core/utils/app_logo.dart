import 'package:flutter/material.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';

Widget appLogo([double height = 100, double width = 200]) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    child: RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        children: [
          TextSpan(
            text: "Wise ",
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: "Player",
            style: TextStyle(color: AppColor.accentRed),
          ),
        ],
      ),
    ),
  );
}
