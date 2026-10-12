import 'package:flutter/material.dart';
import '../colors/colors.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double height;
  final double width;
  final Color backgroundColor;
  final double borderRadius;
  final Widget child;
  final IconData? icon;
  final double? iconSize;
  final bool isBorderSide;
  final Color borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? iconColor;
  final FocusNode? focusNode;

  const CustomButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.height = 50,
    this.width = double.infinity,
    this.backgroundColor = AppColor.coralRed,
    this.borderRadius = 12,
    this.icon,
    this.iconSize = 18,
    this.isBorderSide = false,
    this.borderColor = AppColor.coralRed,
    this.borderWidth = 1,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.gradient,
    this.iconColor,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final buttonColor = gradient != null
              ? null
              : (backgroundColor == Colors.transparent ? Colors.transparent : backgroundColor);

          return AnimatedScale(
            scale: isFocused ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              height: height,
              width: width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: gradient,
                color: buttonColor,
                border: Border.all(
                  color: isFocused
                      ? AppColor.accentRed
                      : (isBorderSide ? borderColor : Colors.transparent),
                  width: isFocused ? 2.5 : (isBorderSide ? borderWidth : 1.0),
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColor.accentRed.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: InkWell(
                focusNode: focusNode,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: onPressed,
                child: Padding(
                  padding: padding,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: iconSize, color: iconColor ?? Colors.white),
                            const SizedBox(width: 8),
                          ],
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
