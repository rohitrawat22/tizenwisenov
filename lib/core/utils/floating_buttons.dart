import 'package:flutter/material.dart';

import '../colors/colors.dart';

Widget floatingNextButton({
  required VoidCallback onPress,
  Widget child = const Icon(
    Icons.arrow_forward_outlined,
    color: AppColor.brownGrey,
  ),
  Color color = AppColor.white,
}) {
  return FloatingActionButton.small(
    heroTag: null,
    backgroundColor: color,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(35),
    ),
    onPressed: onPress,
    child: child,
  );
}
