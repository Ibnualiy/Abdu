enum PriceTier { retail, wholesale }

/// A wholesale/repeat customer — typically another shop buying to
/// resell. Walk-in retail sales don't need one of these; `customerId`
/// on a Sale is null for those. `balance` isn't stored here — see
/// DatabaseService.getCustomerBalance, which sums LedgerEntry rows, so
/// two offline devices can never disagree about a stored running total.
class Customer {
  final String id;
  final String name;
  final String? phone;
  final PriceTier priceTier;
  final double creditLimit; // 0 = cash-only, no credit allowed
  final DateTime updatedAt;
  final int syncStatus;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.priceTier = PriceTier.wholesale,
    this.creditLimit = 0,
    required this.updatedAt,
    this.syncStatus = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'price_tier': priceTier.name,
        'credit_limit': creditLimit,
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        priceTier: PriceTier.values.firstWhere(
          (t) => t.name == map['price_tier'],
          orElse: () => PriceTier.wholesale,
        ),
        creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
      );
}
