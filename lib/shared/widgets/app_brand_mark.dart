import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

class AppBrandMark extends StatelessWidget {
  final double size;
  final bool showLabel;

  const AppBrandMark({
    super.key,
    this.size = 88,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.42;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
                AppColors.accent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.home_work_rounded,
                  size: iconSize,
                  color: Colors.white,
                ),
                Positioned(
                  right: size * 0.19,
                  top: size * 0.22,
                  child: Container(
                    width: size * 0.12,
                    height: size * 0.12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 14),
          Text(
            AppStrings.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
          ),
        ],
      ],
    );
  }
}
