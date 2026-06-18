import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _StatusConfig _getConfig() {
    switch (status) {
      case 'paid':
        return _StatusConfig(AppColors.paidColor, AppStrings.statusPaid);
      case 'partial':
        return _StatusConfig(AppColors.partialColor, AppStrings.statusPartial);
      case 'active':
        return _StatusConfig(AppColors.paidColor, AppStrings.statusActive);
      case 'left':
        return _StatusConfig(AppColors.pendingColor, AppStrings.statusLeft);
      default:
        return _StatusConfig(AppColors.pendingColor, AppStrings.statusPending);
    }
  }
}

class _StatusConfig {
  final Color color;
  final String label;
  _StatusConfig(this.color, this.label);
}
