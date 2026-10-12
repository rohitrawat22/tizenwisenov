import 'package:flutter/material.dart';
import '../../../../core/colors/colors.dart';

class TabChangeButton extends StatelessWidget {
  const TabChangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSidebarItem(
          icon: Icons.home_rounded,
          color: AppColor.coralRed,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _buildSidebarItem(
          icon: Icons.search_rounded,
          color: AppColor.moreLightGrey,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _buildSidebarItem(
          icon: Icons.live_tv_rounded,
          color: AppColor.moreLightGrey,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _buildSidebarItem(
          icon: Icons.favorite_rounded,
          color: AppColor.moreLightGrey,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _buildSidebarItem(
          icon: Icons.person_rounded,
          color: AppColor.moreLightGrey,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFocused
                      ? Colors.white
                      : AppColor.surfaceDark.withOpacity(0.5),
                  border: Border.all(
                    color: isFocused ? Colors.white : Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  icon,
                  color: isFocused ? AppColor.background : color,
                  size: 22,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
