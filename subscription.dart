enum PlanTier { free, premium, distributor }

/// Free tier caps product count as the upgrade nudge — everything else
/// (sales, dashboard, offline sync) stays fully usable either way.
const int freeTierProductLimit = 20;

enum BillingPeriod { monthly, quarterly, yearly }

extension BillingPeriodDays on BillingPeriod {
  int get days {
    switch (this) {
      case BillingPeriod.monthly:
        return 30;
      case BillingPeriod.quarterly:
        return 90;
      case BillingPeriod.yearly:
        return 365;
    }
  }
}

/// Cached locally so premium status can be checked without internet.
/// [lastVerifiedAt] drives a grace period: if the app hasn't reached the
/// server in [graceDays], treat the merchant as expired even if
/// [expiresAt] hasn't passed, so a bypassed/never-online device can't
/// keep premium forever.
class SubscriptionStatus {
  final PlanTier tier;
  final DateTime? expiresAt;
  final DateTime lastVerifiedAt;
  final int graceDays;

  const SubscriptionStatus({
    required this.tier,
    this.expiresAt,
    required this.lastVerifiedAt,
    this.graceDays = 7,
  });

  bool get isPremiumActive {
    if (tier == PlanTier.free) return false;
    if (expiresAt == null) return false;
    final withinExpiry = DateTime.now().isBefore(expiresAt!);
    final withinGrace = DateTime.now()
        .difference(lastVerifiedAt)
        .inDays < graceDays;
    return withinExpiry && withinGrace;
  }

  Map<String, dynamic> toMap() => {
        'tier': tier.name,
        'expires_at': expiresAt?.toIso8601String(),
        'last_verified_at': lastVerifiedAt.toIso8601String(),
        'grace_days': graceDays,
      };

  factory SubscriptionStatus.fromMap(Map<String, dynamic> map) {
    return SubscriptionStatus(
      tier: PlanTier.values.firstWhere(
        (t) => t.name == map['tier'],
        orElse: () => PlanTier.free,
      ),
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      lastVerifiedAt: DateTime.parse(map['last_verified_at'] as String),
      graceDays: map['grace_days'] as int? ?? 7,
    );
  }

  factory SubscriptionStatus.freeDefault() => SubscriptionStatus(
        tier: PlanTier.free,
        lastVerifiedAt: DateTime.now(),
      );
}
