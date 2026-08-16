import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../theme.dart';

/// Wrap any premium feature in this. Shows [child] when unlocked, or a
/// blurred-out lock card when not — status comes from the cached
/// SubscriptionStatus (see SupabaseService.getCachedStatus), so this
/// works offline too, honoring the grace period already built into
/// SubscriptionStatus.isPremiumActive.
class PremiumGate extends StatelessWidget {
  final SubscriptionStatus status;
  final Widget child;
  final String featureName;
  final VoidCallback? onUpgradeTap;

  const PremiumGate({
    super.key,
    required this.status,
    required this.child,
    required this.featureName,
    this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (status.isPremiumActive) return child;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$featureName ለPremium ደንበኞች ብቻ',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onUpgradeTap,
            child: const Text('Premium ማድረግ'),
          ),
        ],
      ),
    );
  }
}
