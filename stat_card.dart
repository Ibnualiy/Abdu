import 'package:flutter/material.dart';
import '../theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? changeText;
  final bool changeIsPositive;
  final Color accentColor;
  final IconData? warningIcon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.changeText,
    this.changeIsPositive = true,
    this.warningIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (changeText != null)
            Row(
              children: [
                Icon(
                  changeIsPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: changeIsPositive ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    changeText!,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          changeIsPositive ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          if (warningIcon != null)
            Row(
              children: [
                Icon(warningIcon, size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  changeText ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
